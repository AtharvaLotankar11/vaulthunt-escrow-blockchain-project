// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBountyEscrow} from "./interfaces/IBountyEscrow.sol";

/// @title BountyEscrow
/// @notice Holds the reward funds of ONE bug bounty program.
/// @dev Deployed as an EIP-1167 minimal-proxy clone by BountyFactory, so it is set up with
///      `initialize()` instead of a constructor. Only the ReportRegistry may lock, pay or
///      release funds (design decision D2). The company (owner) can deposit and can withdraw
///      only funds that are not locked for a report and not owed to a hunter.
contract BountyEscrow is IBountyEscrow, Initializable, ReentrancyGuard {
    /// @dev Payout tiers are basis points (1 bp = 0.01%) of `fundedAmount`.
    uint16 public constant MAX_BPS = 10_000;
    /// @dev Gas cap used by `claimFor`, which anyone (for example the Registry) may call to push a
    ///      hunter's reward to them. A hunter contract that reverts or burns gas can therefore
    ///      never block anyone else; it can still collect with `claim()`, which has no cap.
    uint256 public constant PUSH_GAS = 100_000;

    struct LockInfo {
        uint256 amount; // amount locked (or, after payment, amount paid)
        bool locked; // true while funds are reserved for a report
        bool settled; // true once the report is paid or released
    }

    address public override registry;
    address public override owner;

    /// @notice Net funds the company has put in (deposits minus withdrawals). Payout tiers
    ///         are a percentage of this number, so a "Critical" reward stays predictable.
    uint256 public fundedAmount;
    uint256 public totalLocked;
    uint256 public totalClaimable;

    uint16[4] private _payoutBps;
    mapping(uint256 reportId => LockInfo) private _locks;
    mapping(address hunter => uint256) public claimable;

    event Deposited(address indexed from, uint256 amount);
    event FundsLocked(uint256 indexed reportId, uint256 amount, Severity severity);
    event HunterCredited(uint256 indexed reportId, address indexed hunter, uint256 amount);
    event FundsReleased(uint256 indexed reportId, uint256 amount);
    event Claimed(address indexed hunter, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "BountyEscrow: caller is not the owner");
        _;
    }

    modifier onlyRegistry() {
        require(msg.sender == registry, "BountyEscrow: caller is not the registry");
        _;
    }

    /// @dev Locks the implementation so nobody can initialize it and take it over.
    constructor() {
        _disableInitializers();
    }

    /// @notice One-time setup, called by the factory right after cloning.
    /// @param registry_ The only address allowed to lock, pay and release funds.
    /// @param owner_ The company that owns this program.
    /// @param bps Payout tiers in basis points: Low, Medium, High, Critical (non-decreasing).
    function initialize(address registry_, address owner_, uint16[4] calldata bps) external payable initializer {
        require(registry_ != address(0), "BountyEscrow: registry is zero address");
        require(owner_ != address(0), "BountyEscrow: owner is zero address");

        uint16 previous = 0;
        for (uint256 i = 0; i < 4; i++) {
            require(bps[i] <= MAX_BPS, "BountyEscrow: payout above 100%");
            require(bps[i] >= previous, "BountyEscrow: payouts must not decrease");
            previous = bps[i];
        }
        require(bps[3] > 0, "BountyEscrow: critical payout is zero");

        registry = registry_;
        owner = owner_;
        _payoutBps = bps;

        if (msg.value > 0) {
            fundedAmount = msg.value;
            emit Deposited(owner_, msg.value);
        }
    }

    // ---------------------------------------------------------------------------------
    // Company actions
    // ---------------------------------------------------------------------------------

    /// @notice Add funds to the program.
    function deposit() external payable onlyOwner {
        require(msg.value > 0, "BountyEscrow: deposit is zero");
        fundedAmount += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Withdraw funds that are not locked for a report and not owed to a hunter.
    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "BountyEscrow: withdraw is zero");
        require(amount <= unlockedBalance(), "BountyEscrow: exceeds unlocked funds");

        fundedAmount = amount >= fundedAmount ? 0 : fundedAmount - amount;

        (bool ok,) = owner.call{value: amount}("");
        require(ok, "BountyEscrow: withdraw failed");
        emit Withdrawn(owner, amount);
    }

    // ---------------------------------------------------------------------------------
    // Registry actions
    // ---------------------------------------------------------------------------------

    /// @notice Reserve the reward for `severity` so the company cannot withdraw it.
    function lock(uint256 reportId, Severity severity) external override onlyRegistry {
        LockInfo storage info = _locks[reportId];
        require(!info.locked && !info.settled, "BountyEscrow: report already locked or settled");

        uint256 amount = rewardFor(severity);
        require(amount > 0, "BountyEscrow: reward is zero");
        require(unlockedBalance() >= amount, "BountyEscrow: insufficient unlocked funds");

        info.amount = amount;
        info.locked = true;
        totalLocked += amount;

        emit FundsLocked(reportId, amount, severity);
    }

    /// @notice Credit the reward for `severity` to the hunter. Any earlier lock for this report
    ///         is replaced, so the final severity can differ from the severity first locked.
    /// @dev This function only does bookkeeping (no ETH leaves here). The money is delivered by
    ///      `claimFor(hunter)` (anyone may call it; the Registry does so right after accepting)
    ///      or by the hunter calling `claim()`. Keeping the ETH transfer in a separate function
    ///      means state is always written before any external call.
    function payHunter(uint256 reportId, address hunter, Severity severity) external override onlyRegistry {
        require(hunter != address(0), "BountyEscrow: hunter is zero address");

        LockInfo storage info = _locks[reportId];
        require(!info.settled, "BountyEscrow: report already settled");

        if (info.locked) {
            totalLocked -= info.amount;
            info.locked = false;
        }

        uint256 amount = rewardFor(severity);
        require(amount > 0, "BountyEscrow: reward is zero");
        require(unlockedBalance() >= amount, "BountyEscrow: insufficient unlocked funds");

        info.amount = amount;
        info.settled = true;

        claimable[hunter] += amount;
        totalClaimable += amount;

        emit HunterCredited(reportId, hunter, amount);
    }

    /// @notice Give a report's reserved funds back to the company's unlocked balance
    ///         (the funds never left the escrow). Also closes the report.
    function refundCompany(uint256 reportId) external override onlyRegistry {
        LockInfo storage info = _locks[reportId];
        require(!info.settled, "BountyEscrow: report already settled");

        uint256 released = 0;
        if (info.locked) {
            released = info.amount;
            totalLocked -= released;
            info.locked = false;
        }
        info.settled = true;

        emit FundsReleased(reportId, released);
    }

    // ---------------------------------------------------------------------------------
    // Paying out credited rewards
    // ---------------------------------------------------------------------------------

    /// @notice Collect your own credited reward. No gas cap, so smart-contract wallets work.
    function claim() external nonReentrant {
        uint256 amount = _debit(msg.sender);

        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "BountyEscrow: claim failed");
        emit Claimed(msg.sender, amount);
    }

    /// @notice Push a hunter's credited reward to them. Anyone may call this (the Registry
    ///         does it right after accepting a report). The hunter gets at most `PUSH_GAS`
    ///         gas, so a hunter that reverts or burns gas can only fail its own payout.
    function claimFor(address hunter) external override nonReentrant {
        uint256 amount = _debit(hunter);

        bool ok;
        // Low-level call so the hunter cannot make us copy a huge return value ("return bomb").
        assembly ("memory-safe") {
            ok := call(PUSH_GAS, hunter, amount, 0, 0, 0, 0)
        }
        require(ok, "BountyEscrow: claim failed");
        emit Claimed(hunter, amount);
    }

    /// @dev Zero out a hunter's credit BEFORE any ETH is sent (checks-effects-interactions).
    function _debit(address hunter) private returns (uint256 amount) {
        amount = claimable[hunter];
        require(amount > 0, "BountyEscrow: nothing to claim");

        claimable[hunter] = 0;
        totalClaimable -= amount;
    }

    // ---------------------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------------------

    /// @notice Funds the company could withdraw right now.
    function unlockedBalance() public view returns (uint256) {
        uint256 reserved = totalLocked + totalClaimable;
        uint256 balance = address(this).balance;
        return balance > reserved ? balance - reserved : 0;
    }

    /// @notice Payout tier in basis points.
    function payoutBps(Severity severity) external view returns (uint16) {
        return _payoutBps[uint8(severity)];
    }

    /// @notice Reward in wei for a severity, based on `fundedAmount`.
    function rewardFor(Severity severity) public view returns (uint256) {
        return (fundedAmount * _payoutBps[uint8(severity)]) / MAX_BPS;
    }

    function lockOf(uint256 reportId) external view returns (uint256 amount, bool locked, bool settled) {
        LockInfo storage info = _locks[reportId];
        return (info.amount, info.locked, info.settled);
    }
}
