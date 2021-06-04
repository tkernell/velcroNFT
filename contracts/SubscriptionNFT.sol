// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IPlanController {
    function isSubActive(uint256 nftId) external view returns(bool); 
}

contract SubscriptionNFT is ERC721 {
    address public owner;
    uint256 counter;
    
    /**
     * @dev Constructor which sets NFT parameters
     * @param _owner Owner of this contract
     */
    constructor(address _owner) ERC721("Velcro NFT Subscription", "VEL") {
        owner = _owner;
    }
    
    /**
     * @dev Mint new NFT
     * @param _to Recipient of NFT
     */
    function mint(address _to) public returns(uint256) {
        require(msg.sender == owner);
        _mint(_to, counter);
        counter++;
        return(counter-1);
    }
    
    /**
     * @dev Get owner of active subscription NFT 
     * @param _nftId ID of NFT
     * @return address NFT owner or zero address if subscription expired
     */
    function ownerOf(uint256 _nftId) public view override returns(address) {
        if (IPlanController(owner).isSubActive(_nftId)) {
            return(super.ownerOf(_nftId));
        } else {
            return(address(0));
        }
    }
    
    /**
     * @dev Get owner of active or inactive NFT 
     * @param _nftId ID of NFT
     * @return address NFT owner
     */
    function interestOwnerOf(uint256 _nftId) public view returns(address) {
        return(super.ownerOf(_nftId));
    }
}
