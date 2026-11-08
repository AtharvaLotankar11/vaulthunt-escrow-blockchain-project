// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReportRegistry} from "../src/ReportRegistry.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";
import {BountyFactory} from "../src/BountyFactory.sol";
import {ReputationSBT} from "../src/ReputationSBT.sol";
import {IBountyEscrow} from "../src/interfaces/IBountyEscrow.sol";
import {RegistryBase, MockCourt, ContractHunter, GasBurnReceiver} from "./RegistryBase.sol";

contract ReportRegistryTest is RegistryBase {
    ReportRegistry.Status internal constant COMMITTED = ReportRegistry.Status.Committed;
    ReportRegistry.Status internal constant REVEALED = ReportRegistry.Status.Revealed;
    ReportRegistry.Status internal constant UNDER_REVIEW = ReportRegistry.Status.UnderReview;
    ReportRegistry.Status internal constant REJECTED = ReportRegistry.Status.Rejected;
    ReportRegistry.Status internal constant DISPUTED = ReportRegistry.Status.Disputed;
    ReportRegistry.Status internal constant PAID = ReportRegistry.Status.Paid;
    ReportRegistry.Status internal constant REFUNDED = ReportRegistry.Status.Refunded;

    // ------------------------------------------------------------------ constructor / court

    function testConstructorSetsConfiguration() public view {
        assertEq(address(registry.factory()), address(factory));
        assertEq(address(registry.sbt()), address(sbt));
        assertEq(registry.reviewPeriod(), PERIOD);
        assertEq(registry.revealWindow(), PERIOD);
        assertEq(registry.disputeWindow(), PERIOD);
        assertEq(registry.owner(), address(this));
        assertEq(registry.court(), address(court));
        assertEq(registry.reportCount(), 0);
    }

    function testConstructorRejectsZeroFactory() public {
        vm.expectRevert("ReportRegistry: factory is zero address");
        new ReportRegistry(address(0), address(sbt), PERIOD, PERIOD, PERIOD);
    }

    function testConstructorRejectsZeroSbt() public {
        vm.expectRevert("ReportRegistry: sbt is zero address");
        new ReportRegistry(address(factory), address(0), PERIOD, PERIOD, PERIOD);
    }

    function testConstructorRejectsZeroPeriods() public {
        vm.expectRevert("ReportRegistry: period is zero");
        new ReportRegistry(address(factory), address(sbt), 0, PERIOD, PERIOD);
        vm.expectRevert("ReportRegistry: period is zero");
        new ReportRegistry(address(factory), address(sbt), PERIOD, 0, PERIOD);
        vm.expectRevert("ReportRegistry: period is zero");
        new ReportRegistry(address(factory), address(sbt), PERIOD, PERIOD, 0);
    }

    function testSetCourtOnlyOnce() public {
        Env memory e = _newEnvironment(bps, false, true);
        assertEq(e.registry.court(), address(0));

        vm.expectEmit(true, false, false, false);
        emit ReportRegistry.CourtSet(address(e.court));
        e.registry.setCourt(address(e.court));
        assertEq(e.registry.court(), address(e.court));

        vm.expectRevert("ReportRegistry: court already set");
        e.registry.setCourt(makeAddr("another"));
    }

    function testSetCourtZeroAddressReverts() public {
        Env memory e = _newEnvironment(bps, false, true);
        vm.expectRevert("ReportRegistry: court is zero address");
        e.registry.setCourt(address(0));
    }

    function testSetCourtOnlyOwner() public {
        Env memory e = _newEnvironment(bps, false, true);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        e.registry.setCourt(address(e.court));
    }

    // ------------------------------------------------------------------ commit

    function testCommitStoresReport() public {
        bytes32 commitHash = _commitHash(CONTENT, SALT, hunter);

        vm.expectEmit(true, true, true, true);
        emit ReportRegistry.ReportCommitted(1, programId, hunter, commitHash, uint64(block.timestamp));
        uint256 id = _commit(hunter, CONTENT, SALT);

        assertEq(id, 1);
        assertEq(registry.reportCount(), 1);
        assertTrue(registry.commitUsed(commitHash));

        ReportRegistry.Report memory r = registry.getReport(id);
        assertEq(r.programId, programId);
        assertEq(r.escrow, address(escrow));
        assertEq(r.hunter, hunter);
        assertTrue(r.status == COMMITTED);
        assertEq(r.commitHash, commitHash);
        assertEq(r.committedAt, uint64(block.timestamp));
        assertEq(r.contentHash, bytes32(0));
        assertEq(bytes(r.cid).length, 0);
    }

    function testCommitTracksReportLists() public {
        uint256 a = _commit(hunter, CONTENT, SALT);
        uint256 b = _commit(hunter, keccak256("another"), SALT);
        uint256 c = _commit(hunter2, CONTENT, SALT);

        uint256[] memory program = registry.programReportIds(programId);
        assertEq(program.length, 3);
        assertEq(program[0], a);
        assertEq(program[2], c);

        uint256[] memory mine = registry.hunterReportIds(hunter);
        assertEq(mine.length, 2);
        assertEq(mine[1], b);
        assertEq(registry.hunterReportIds(hunter2).length, 1);
        assertEq(registry.hunterReportIds(stranger).length, 0);
    }

    function testCommitZeroHashReverts() public {
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: empty commit hash");
        registry.commitReport(programId, bytes32(0));
    }

    function testCommitSameHashTwiceReverts() public {
        _commit(hunter, CONTENT, SALT);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: commit hash already used");
        registry.commitReport(programId, _commitHash(CONTENT, SALT, hunter));
    }

    function testCommitUnknownProgramReverts() public {
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: unknown program");
        registry.commitReport(999, keccak256("x"));
    }

    function testCommitOnProgramLinkedToAnotherRegistryReverts() public {
        // a second Registry that shares the factory, but the program's escrow trusts the first
        ReportRegistry other = new ReportRegistry(address(factory), address(sbt), PERIOD, PERIOD, PERIOD);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: program not linked to this registry");
        other.commitReport(programId, keccak256("x"));
    }

    function testTwoHuntersCommitSameBugEarliestCommitIsRecorded() public {
        uint256 first = _commit(hunter, CONTENT, SALT);
        vm.warp(block.timestamp + 1 hours);
        uint256 second = _commit(hunter2, CONTENT, SALT); // same bug, same content

        // the hashes differ because each one is bound to its hunter's address
        assertTrue(_commitHash(CONTENT, SALT, hunter) != _commitHash(CONTENT, SALT, hunter2));
        // and the contract records who was first
        assertLt(registry.getReport(first).committedAt, registry.getReport(second).committedAt);
    }

    // ------------------------------------------------------------------ reveal

    function testRevealLocksFundsAndStoresData() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        uint64 deadline = uint64(block.timestamp + PERIOD);

        vm.expectEmit(true, true, false, true);
        emit ReportRegistry.ReportRevealed(id, hunter, "bafyTestCid", CONTENT, HIGH, deadline);
        _reveal(hunter, id, CONTENT, SALT, HIGH);

        ReportRegistry.Report memory r = registry.getReport(id);
        assertTrue(r.status == REVEALED);
        assertEq(r.cid, "bafyTestCid");
        assertEq(r.contentHash, CONTENT);
        assertTrue(r.claimedSeverity == HIGH);
        assertEq(r.revealedAt, uint64(block.timestamp));
        assertEq(r.reviewDeadline, deadline);

        // the reward (30% of 10 ETH) is reserved in the escrow
        assertEq(escrow.totalLocked(), 3 ether);
        (uint256 amount, bool locked,) = escrow.lockOf(id);
        assertEq(amount, 3 ether);
        assertTrue(locked);
    }

    function testRevealWithWrongSaltReverts() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: reveal does not match commit");
        registry.revealReport(id, "cid", CONTENT, keccak256("wrong-salt"), HIGH);
    }

    function testRevealWithWrongContentReverts() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: reveal does not match commit");
        registry.revealReport(id, "cid", keccak256("other-content"), SALT, HIGH);
    }

    function testRevealByAnotherAddressReverts() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        vm.prank(hunter2);
        vm.expectRevert("ReportRegistry: caller is not the hunter");
        registry.revealReport(id, "cid", CONTENT, SALT, HIGH);
    }

    function testCopiedCommitCannotBeReusedByAnotherHunter() public {
        _commit(hunter, CONTENT, SALT);
        // hunter2 sees hunter's commit hash on-chain and tries to commit the very same hash
        vm.prank(hunter2);
        vm.expectRevert("ReportRegistry: commit hash already used");
        registry.commitReport(programId, _commitHash(CONTENT, SALT, hunter));
    }

    function testRevealTwiceReverts() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: report is not in Committed state");
        registry.revealReport(id, "cid", CONTENT, SALT, HIGH);
    }

    function testRevealAfterWindowReverts() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        vm.warp(block.timestamp + PERIOD + 1);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: reveal window closed");
        registry.revealReport(id, "cid", CONTENT, SALT, HIGH);
    }

    function testRevealAtExactWindowEndStillWorks() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        vm.warp(block.timestamp + PERIOD);
        _reveal(hunter, id, CONTENT, SALT, HIGH);
        assertTrue(_statusOf(id) == REVEALED);
    }

    function testRevealEmptyCidReverts() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: empty CID");
        registry.revealReport(id, "", CONTENT, SALT, HIGH);
    }

    function testRevealUnknownReportReverts() public {
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: report is not in Committed state");
        registry.revealReport(42, "cid", CONTENT, SALT, HIGH);
    }

    function testRevealRevertsWhenProgramCannotCoverReward() public {
        vm.prank(company);
        (uint256 emptyProgram,) = factory.createProgram(company, bps); // no funding
        uint256 id = _commitOn(registry, emptyProgram, hunter, CONTENT, SALT);

        vm.prank(hunter);
        vm.expectRevert("BountyEscrow: reward is zero");
        registry.revealReport(id, "cid", CONTENT, SALT, HIGH);
        assertTrue(_statusOf(id) == COMMITTED); // nothing changed, hunter can retry after a top-up
    }

    // ------------------------------------------------------------------ startReview

    function testStartReviewMovesToUnderReview() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);

        vm.expectEmit(true, false, false, false);
        emit ReportRegistry.ReviewStarted(id);
        vm.prank(company);
        registry.startReview(id);

        assertTrue(_statusOf(id) == UNDER_REVIEW);
    }

    function testStartReviewOnlyProgramOwner() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: caller is not the program owner");
        registry.startReview(id);
        vm.prank(stranger);
        vm.expectRevert("ReportRegistry: caller is not the program owner");
        registry.startReview(id);
    }

    function testStartReviewWrongStatusReverts() public {
        uint256 id = _commit(hunter, CONTENT, SALT); // still Committed
        vm.prank(company);
        vm.expectRevert("ReportRegistry: report is not in Revealed state");
        registry.startReview(id);
    }

    function testStartReviewUnknownReportReverts() public {
        vm.prank(company);
        vm.expectRevert("ReportRegistry: unknown report");
        registry.startReview(77);
    }

    // ------------------------------------------------------------------ accept

    function testAcceptPaysHunterAndMintsBadge() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);

        vm.expectEmit(true, true, false, true);
        emit ReportRegistry.RewardPaid(id, hunter, HIGH);
        vm.prank(company);
        registry.acceptReport(id, HIGH);

        ReportRegistry.Report memory r = registry.getReport(id);
        assertTrue(r.status == PAID);
        assertTrue(r.paidSeverity == HIGH);
        assertEq(hunter.balance, 3 ether); // pushed straight to the hunter
        assertEq(address(escrow).balance, 7 ether);
        assertEq(escrow.totalLocked(), 0);
        assertEq(escrow.claimable(hunter), 0);

        // reputation: 50 XP, still level 1, badge minted
        assertEq(registry.hunterXp(hunter), 50);
        assertTrue(registry.hasBadge(hunter));
        assertEq(registry.badgeOf(hunter), 0);
        assertEq(sbt.ownerOf(0), hunter);
        (uint256 level, uint256 xp) = sbt.getReputation(0);
        assertEq(level, 1);
        assertEq(xp, 50);
    }

    function testAcceptFromUnderReviewWorks() public {
        uint256 id = _submit(hunter, CONTENT, SALT, LOW);
        vm.startPrank(company);
        registry.startReview(id);
        registry.acceptReport(id, LOW);
        vm.stopPrank();
        assertTrue(_statusOf(id) == PAID);
        assertEq(hunter.balance, 0.5 ether);
    }

    function testAcceptCanChooseADifferentSeverity() public {
        uint256 id = _submit(hunter, CONTENT, SALT, LOW); // hunter claimed Low (0.5 ETH locked)
        vm.prank(company);
        registry.acceptReport(id, CRITICAL); // company rates it Critical (5 ETH)

        assertEq(hunter.balance, 5 ether);
        assertEq(escrow.totalLocked(), 0);
        assertEq(registry.hunterXp(hunter), 100);
        (uint256 level,) = sbt.getReputation(0);
        assertEq(level, 2); // 100 XP = Hacker
    }

    function testAcceptOnlyProgramOwner() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: caller is not the program owner");
        registry.acceptReport(id, HIGH);
        vm.prank(stranger);
        vm.expectRevert("ReportRegistry: caller is not the program owner");
        registry.acceptReport(id, HIGH);
    }

    function testAcceptUnknownReportReverts() public {
        vm.prank(company);
        vm.expectRevert("ReportRegistry: unknown report");
        registry.acceptReport(5, HIGH);
    }

    function testAcceptWrongStatusReverts() public {
        uint256 committed = _commit(hunter, CONTENT, SALT);
        vm.prank(company);
        vm.expectRevert("ReportRegistry: report is not awaiting review");
        registry.acceptReport(committed, HIGH);

        uint256 rejected = _submit(hunter2, CONTENT, SALT, LOW);
        vm.startPrank(company);
        registry.rejectReport(rejected);
        vm.expectRevert("ReportRegistry: report is not awaiting review");
        registry.acceptReport(rejected, LOW);
        vm.stopPrank();
    }

    function testAcceptTwiceReverts() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.startPrank(company);
        registry.acceptReport(id, HIGH);
        vm.expectRevert("ReportRegistry: report is not awaiting review");
        registry.acceptReport(id, HIGH);
        vm.stopPrank();
        assertEq(hunter.balance, 3 ether); // paid once only
    }

    function testAcceptRevertsWhenEscrowCannotCoverHigherSeverity() public {
        uint256 low = _submit(hunter, keccak256("a"), SALT, LOW); // 0.5 locked
        _submit(hunter2, keccak256("b"), SALT, CRITICAL); // 5 locked
        _submit(stranger, keccak256("c"), SALT, HIGH); // 3 locked -> 8.5 locked, 1.5 free

        vm.prank(company);
        vm.expectRevert("BountyEscrow: insufficient unlocked funds");
        registry.acceptReport(low, CRITICAL); // would need 5, only 1.5 + its own 0.5 are free
        assertTrue(_statusOf(low) == REVEALED); // the revert rolled everything back
        assertEq(registry.hunterXp(hunter), 0);
    }

    function testBadgeIsMintedOnlyOncePerHunter() public {
        uint256 a = _submit(hunter, keccak256("a"), SALT, LOW);
        uint256 b = _submit(hunter, keccak256("b"), SALT, LOW);
        vm.startPrank(company);
        registry.acceptReport(a, LOW);
        registry.acceptReport(b, MEDIUM);
        vm.stopPrank();

        assertEq(sbt.balanceOf(hunter), 1);
        assertEq(registry.hunterXp(hunter), 35);
        (, uint256 xp) = sbt.getReputation(registry.badgeOf(hunter));
        assertEq(xp, 35);
    }

    function testXpAndLevelsProgressToLegend() public {
        uint16[4] memory tiny = [uint16(1), 1, 1, 1]; // 0.01% so many reports fit one program
        Env memory e = _newEnvironment(tiny, true, true);

        for (uint256 i = 1; i <= 7; i++) {
            bytes32 content = keccak256(abi.encode("bug", i));
            uint256 id = _commitOn(e.registry, e.programId, hunter, content, SALT);
            _revealOn(e.registry, hunter, id, content, SALT, CRITICAL);
            vm.prank(company);
            e.registry.acceptReport(id, CRITICAL);

            (uint256 level, uint256 xp) = e.sbt.getReputation(e.registry.badgeOf(hunter));
            assertEq(xp, i * 100);
            if (i < 3) assertEq(level, 2);
            else if (i < 7) assertEq(level, 3);
            else assertEq(level, 4);
        }
    }

    function testAcceptStillPaysWhenHunterRejectsEthAndCannotReceiveBadge() public {
        ContractHunter ch = new ContractHunter(); // refuses ETH, has no onERC721Received
        bytes32 commitHash = _commitHash(CONTENT, SALT, address(ch));
        uint256 id = ch.commit(registry, programId, commitHash);
        ch.reveal(registry, id, CONTENT, SALT, HIGH);

        vm.prank(company);
        registry.acceptReport(id, HIGH); // must not revert

        assertTrue(_statusOf(id) == PAID);
        assertEq(address(ch).balance, 0); // the push failed...
        assertEq(escrow.claimable(address(ch)), 3 ether); // ...but the credit is safe
        assertFalse(registry.hasBadge(address(ch))); // badge mint failed quietly
        assertEq(registry.hunterXp(address(ch)), 50); // XP is still recorded

        ch.setRejecting(false);
        ch.claimFrom(escrow);
        assertEq(address(ch).balance, 3 ether);
    }

    function testGasBurningBadgeReceiverCannotBlockAccept() public {
        GasBurnReceiver burner = new GasBurnReceiver();
        uint256 id = burner.commit(registry, programId, _commitHash(CONTENT, SALT, address(burner)));
        burner.reveal(registry, id, CONTENT, SALT, HIGH);

        uint256 gasBefore = gasleft();
        vm.prank(company);
        registry.acceptReport(id, HIGH);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(_statusOf(id) == PAID);
        assertEq(address(burner).balance, 3 ether);
        assertFalse(registry.hasBadge(address(burner)));
        assertLt(gasUsed, 2_000_000); // BADGE_GAS (400k) capped the damage
    }

    function testAcceptStillPaysWhenRegistryIsNotTheSbtOwner() public {
        Env memory e = _newEnvironment(bps, true, false); // SBT ownership NOT transferred
        uint256 id = _commitOn(e.registry, e.programId, hunter, CONTENT, SALT);
        _revealOn(e.registry, hunter, id, CONTENT, SALT, HIGH);

        vm.prank(company);
        e.registry.acceptReport(id, HIGH);

        assertEq(hunter.balance, 3 ether);
        assertFalse(e.registry.hasBadge(hunter));
    }

    // ------------------------------------------------------------------ reject / finalize

    function testRejectKeepsFundsLocked() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);

        vm.expectEmit(true, false, false, false);
        emit ReportRegistry.ReportRejected(id);
        vm.prank(company);
        registry.rejectReport(id);

        ReportRegistry.Report memory r = registry.getReport(id);
        assertTrue(r.status == REJECTED);
        assertEq(r.rejectedAt, uint64(block.timestamp));
        assertEq(escrow.totalLocked(), 3 ether); // still reserved for a possible dispute

        vm.prank(company);
        vm.expectRevert("BountyEscrow: exceeds unlocked funds");
        escrow.withdraw(7 ether + 1);
    }

    function testRejectOnlyProgramOwner() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: caller is not the program owner");
        registry.rejectReport(id);
    }

    function testRejectWrongStatusReverts() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        vm.prank(company);
        vm.expectRevert("ReportRegistry: report is not awaiting review");
        registry.rejectReport(id);
    }

    function testFinalizeRejectionRefundsCompanyAfterWindow() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);

        vm.warp(block.timestamp + PERIOD + 1);
        vm.expectEmit(true, false, false, false);
        emit ReportRegistry.RejectionFinalized(id);
        vm.prank(stranger); // anyone may close it
        registry.finalizeRejection(id);

        assertTrue(_statusOf(id) == REFUNDED);
        assertEq(escrow.totalLocked(), 0);

        vm.prank(company);
        escrow.withdraw(10 ether); // everything is the company's again
        assertEq(hunter.balance, 0);
    }

    function testFinalizeRejectionBeforeWindowEndsReverts() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);

        vm.warp(block.timestamp + PERIOD); // exactly at the end: still open
        vm.expectRevert("ReportRegistry: dispute window still open");
        registry.finalizeRejection(id);
    }

    function testFinalizeRejectionRequiresRejectedStatus() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.expectRevert("ReportRegistry: report is not rejected");
        registry.finalizeRejection(id);
    }

    // ------------------------------------------------------------------ escalate

    function testEscalateOpensCaseWithHunterAsFeePayer() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);

        vm.expectEmit(true, true, false, true);
        emit ReportRegistry.ReportEscalated(id, hunter, false);
        vm.prank(hunter);
        registry.escalate(id);

        assertTrue(_statusOf(id) == DISPUTED);
        assertEq(court.calls(), 1);
        assertEq(court.lastReportId(), id);
        assertEq(court.lastHunter(), hunter);
        assertEq(court.lastFeePayer(), hunter);
        assertEq(escrow.totalLocked(), 3 ether); // still reserved
    }

    function testEscalateAtExactWindowEndStillWorks() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);
        vm.warp(block.timestamp + PERIOD);
        vm.prank(hunter);
        registry.escalate(id);
        assertTrue(_statusOf(id) == DISPUTED);
    }

    function testEscalateOnlyHunter() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);
        vm.prank(stranger);
        vm.expectRevert("ReportRegistry: caller is not the hunter");
        registry.escalate(id);
    }

    function testEscalateRequiresRejection() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: report is not rejected");
        registry.escalate(id);
    }

    function testEscalateAfterWindowReverts() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);
        vm.warp(block.timestamp + PERIOD + 1);
        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: dispute window closed");
        registry.escalate(id);
    }

    function testEscalateRevertsWhenCourtNotSet() public {
        Env memory e = _newEnvironment(bps, false, true);
        uint256 id = _commitOn(e.registry, e.programId, hunter, CONTENT, SALT);
        _revealOn(e.registry, hunter, id, CONTENT, SALT, HIGH);
        vm.prank(company);
        e.registry.rejectReport(id);

        vm.prank(hunter);
        vm.expectRevert("ReportRegistry: court not set");
        e.registry.escalate(id);
    }

    function testEscalateIsAtomicWhenCourtReverts() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);
        court.setShouldRevert(true);

        vm.prank(hunter);
        vm.expectRevert("MockCourt: reverting");
        registry.escalate(id);
        assertTrue(_statusOf(id) == REJECTED); // nothing half-done
    }

    // ------------------------------------------------------------------ timeout escalation

    function testEscalateAfterTimeoutBeforeDeadlineReverts() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.warp(block.timestamp + PERIOD); // exactly at the deadline: not yet
        vm.expectRevert("ReportRegistry: review deadline not reached");
        registry.escalateAfterTimeout(id);
    }

    function testEscalateAfterTimeoutByAnyone() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.warp(block.timestamp + PERIOD + 1);

        vm.expectEmit(true, true, false, true);
        emit ReportRegistry.ReportEscalated(id, hunter, true);
        vm.prank(stranger);
        registry.escalateAfterTimeout(id);

        assertTrue(_statusOf(id) == DISPUTED);
        assertEq(court.calls(), 1);
        assertEq(court.lastFeePayer(), address(0)); // the company's silence is not the hunter's cost
        assertEq(court.lastHunter(), hunter);
    }

    function testEscalateAfterTimeoutWorksFromUnderReview() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.startReview(id);
        vm.warp(block.timestamp + PERIOD + 1);
        registry.escalateAfterTimeout(id);
        assertTrue(_statusOf(id) == DISPUTED);
    }

    function testEscalateAfterTimeoutWrongStatusReverts() public {
        uint256 committed = _commit(hunter, CONTENT, SALT);
        vm.expectRevert("ReportRegistry: report is not awaiting review");
        registry.escalateAfterTimeout(committed);

        uint256 paid = _submit(hunter2, CONTENT, SALT, LOW);
        vm.prank(company);
        registry.acceptReport(paid, LOW);
        vm.warp(block.timestamp + PERIOD + 1);
        vm.expectRevert("ReportRegistry: report is not awaiting review");
        registry.escalateAfterTimeout(paid);
    }

    function testEscalateAfterTimeoutRevertsWhenCourtNotSet() public {
        Env memory e = _newEnvironment(bps, false, true);
        uint256 id = _commitOn(e.registry, e.programId, hunter, CONTENT, SALT);
        _revealOn(e.registry, hunter, id, CONTENT, SALT, HIGH);
        vm.warp(block.timestamp + PERIOD + 1);
        vm.expectRevert("ReportRegistry: court not set");
        e.registry.escalateAfterTimeout(id);
    }

    function testCompanyCanStillAcceptAfterDeadlineIfNobodyEscalated() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.warp(block.timestamp + PERIOD + 10 days);
        vm.prank(company);
        registry.acceptReport(id, HIGH);
        assertTrue(_statusOf(id) == PAID);
    }

    // ------------------------------------------------------------------ verdict

    function _disputedReport() internal returns (uint256 id) {
        id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.prank(company);
        registry.rejectReport(id);
        vm.prank(hunter);
        registry.escalate(id);
    }

    function testVerdictForHunterPaysTheClaimedSeverity() public {
        uint256 id = _disputedReport();

        vm.expectEmit(true, false, false, true);
        emit ReportRegistry.VerdictApplied(id, true);
        court.verdict(registry, id, true);

        ReportRegistry.Report memory r = registry.getReport(id);
        assertTrue(r.status == PAID);
        assertTrue(r.paidSeverity == HIGH);
        assertEq(hunter.balance, 3 ether);
        assertEq(escrow.totalLocked(), 0);
        assertEq(registry.hunterXp(hunter), 50);
        assertTrue(registry.hasBadge(hunter));
    }

    function testVerdictForCompanyRefundsTheCompany() public {
        uint256 id = _disputedReport();

        vm.expectEmit(true, false, false, true);
        emit ReportRegistry.VerdictApplied(id, false);
        court.verdict(registry, id, false);

        assertTrue(_statusOf(id) == REFUNDED);
        assertEq(hunter.balance, 0);
        assertEq(escrow.totalLocked(), 0);
        assertEq(registry.hunterXp(hunter), 0);
        assertFalse(registry.hasBadge(hunter));

        vm.prank(company);
        escrow.withdraw(10 ether);
    }

    function testVerdictAfterTimeoutEscalationWorksToo() public {
        uint256 id = _submit(hunter, CONTENT, SALT, CRITICAL);
        vm.warp(block.timestamp + PERIOD + 1);
        registry.escalateAfterTimeout(id);
        court.verdict(registry, id, true);
        assertEq(hunter.balance, 5 ether);
    }

    function testVerdictOnlyFromCourt() public {
        uint256 id = _disputedReport();
        vm.prank(stranger);
        vm.expectRevert("ReportRegistry: caller is not the court");
        registry.applyVerdict(id, true);
        vm.prank(company);
        vm.expectRevert("ReportRegistry: caller is not the court");
        registry.applyVerdict(id, false);
    }

    function testVerdictOnNonDisputedReportReverts() public {
        uint256 id = _submit(hunter, CONTENT, SALT, HIGH);
        vm.expectRevert("ReportRegistry: report is not disputed");
        court.verdict(registry, id, true);
    }

    function testVerdictTwiceReverts() public {
        uint256 id = _disputedReport();
        court.verdict(registry, id, true);
        vm.expectRevert("ReportRegistry: report is not disputed");
        court.verdict(registry, id, true);
        assertEq(hunter.balance, 3 ether); // paid once only
    }

    // ------------------------------------------------------------------ views

    function testSeverityXpValues() public view {
        assertEq(registry.severityXp(LOW), 10);
        assertEq(registry.severityXp(MEDIUM), 25);
        assertEq(registry.severityXp(HIGH), 50);
        assertEq(registry.severityXp(CRITICAL), 100);
    }

    function testLevelBoundaries() public view {
        assertEq(registry.levelFor(0), 1);
        assertEq(registry.levelFor(99), 1);
        assertEq(registry.levelFor(100), 2);
        assertEq(registry.levelFor(299), 2);
        assertEq(registry.levelFor(300), 3);
        assertEq(registry.levelFor(699), 3);
        assertEq(registry.levelFor(700), 4);
        assertEq(registry.levelFor(1_000_000), 4);
    }

    function testProgramOwnerOf() public {
        uint256 id = _commit(hunter, CONTENT, SALT);
        assertEq(registry.programOwnerOf(id), company);
    }

    function testProgramOwnerOfUnknownReportReverts() public {
        vm.expectRevert("ReportRegistry: unknown report");
        registry.programOwnerOf(1);
    }

    function testGetReportOfUnknownIdIsEmpty() public view {
        ReportRegistry.Report memory r = registry.getReport(123);
        assertTrue(r.status == ReportRegistry.Status.None);
        assertEq(r.hunter, address(0));
    }
}
