// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {IBountyEscrow} from "./interfaces/IBountyEscrow.sol";
import {IBountyFactory} from "./interfaces/IBountyFactory.sol";

/// @title ProgramDirectory
/// @notice Lets a program's company publish a pointer (an IPFS content id) to its public
///         profile: name, scope text and the PUBLIC encryption key hunters use to encrypt
///         their reports. The profile itself lives off-chain; only the pointer is on-chain.
/// @dev Only the program's owner (read from its escrow) may set or change the pointer. The
///      directory holds no funds and has no admin.
contract ProgramDirectory {
    uint256 public constant MAX_URI_LENGTH = 160;

    IBountyFactory public immutable factory;

    mapping(uint256 programId => string) private _profileURI;
    mapping(uint256 programId => uint64) public profileVersion;

    event ProfileSet(uint256 indexed programId, address indexed programOwner, string uri, uint64 version);

    constructor(address factory_) {
        require(factory_ != address(0), "ProgramDirectory: factory is zero address");
        factory = IBountyFactory(factory_);
    }

    /// @notice Publish or update the profile pointer of a program you own.
    function setProfile(uint256 programId, string calldata uri) external {
        address escrow = factory.programs(programId);
        require(escrow != address(0), "ProgramDirectory: unknown program");
        require(IBountyEscrow(escrow).owner() == msg.sender, "ProgramDirectory: caller is not the program owner");
        require(bytes(uri).length > 0, "ProgramDirectory: empty uri");
        require(bytes(uri).length <= MAX_URI_LENGTH, "ProgramDirectory: uri too long");

        _profileURI[programId] = uri;
        uint64 version = profileVersion[programId] + 1;
        profileVersion[programId] = version;
        emit ProfileSet(programId, msg.sender, uri, version);
    }

    /// @notice The profile pointer of a program, or an empty string if none was published.
    function profileURI(uint256 programId) external view returns (string memory) {
        return _profileURI[programId];
    }
}
