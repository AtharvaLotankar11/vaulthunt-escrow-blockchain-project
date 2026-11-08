// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReputationSBT
 * @notice Soulbound ERC-721 token for hunter reputation badges
 * @dev Non-transferable after minting (soulbound implementation via _update override)
 */
contract ReputationSBT is ERC721, Ownable {
    struct HunterReputation {
        uint256 level;
        uint256 xp;
    }
    
    mapping(uint256 => HunterReputation) public reputations;
    uint256 private _nextTokenId;
    
    event LevelUpdated(uint256 indexed tokenId, uint256 level, uint256 xp);
    
    /**
     * @notice Constructor
     */
    constructor() ERC721("VaultHunt Reputation", "VHREP") Ownable(msg.sender) {}
    
    /**
     * @notice Mint a new reputation badge to a hunter
     * @param hunter Address to mint the badge to
     * @return tokenId The ID of the newly minted token
     */
    function mint(address hunter) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(hunter, tokenId);
        
        reputations[tokenId] = HunterReputation({
            level: 1,
            xp: 0
        });
        
        return tokenId;
    }
    
    /**
     * @notice Update the level and XP of a reputation badge
     * @param tokenId Token ID to update
     * @param newLevel New level
     * @param newXP New XP amount
     */
    function updateLevel(uint256 tokenId, uint256 newLevel, uint256 newXP) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "ReputationSBT: token does not exist");
        
        reputations[tokenId].level = newLevel;
        reputations[tokenId].xp = newXP;
        
        emit LevelUpdated(tokenId, newLevel, newXP);
    }
    
    /**
     * @notice Get reputation data for a token
     * @param tokenId Token ID to query
     * @return level Hunter's level
     * @return xp Hunter's XP
     */
    function getReputation(uint256 tokenId) external view returns (uint256 level, uint256 xp) {
        require(_ownerOf(tokenId) != address(0), "ReputationSBT: token does not exist");
        HunterReputation memory rep = reputations[tokenId];
        return (rep.level, rep.xp);
    }
    
    /**
     * @notice Override _update to implement soulbound behavior
     * @dev Allows minting (from == address(0)) but reverts on transfers
     * Exact signature from OpenZeppelin ERC721 v5.7.0
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Allow minting (from == address(0))
        // Revert on any transfer attempt (from != address(0) and to != address(0))
        if (from != address(0) && to != address(0)) {
            revert("ReputationSBT: token is soulbound and cannot be transferred");
        }
        
        // Call parent implementation for mint/burn
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @notice Generate token URI (placeholder implementation)
     * @param tokenId Token ID
     * @return URI string
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ReputationSBT: token does not exist");
        
        HunterReputation memory rep = reputations[tokenId];
        
        // Placeholder: in production this would return IPFS metadata with level/XP
        return string(abi.encodePacked(
            "data:application/json;base64,",
            "eyJuYW1lIjoiVmF1bHRIdW50IFJlcHV0YXRpb24iLCJsZXZlbCI6",
            _toString(rep.level),
            "}"
        ));
    }
    
    /**
     * @dev Convert uint256 to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
