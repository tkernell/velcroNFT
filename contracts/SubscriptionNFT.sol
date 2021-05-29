// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IPlanController {
    function isSubActive(uint256 nftId) external view returns(bool); 
}

contract SubscriptionNFT is ERC721 {
    address public owner;
    uint256 counter;

    constructor(address _owner) ERC721("Velcro NFT Subscription", "VEL") {
        // __ERC721_init("Velcro NFT Subscription", "VEL");
        owner = _owner;
    }

    function mint(address _to) public returns(uint256) {
        require(msg.sender == owner);
        _mint(_to, counter);
        counter++;
        return(counter-1);
    }
    
    function ownerOf(uint256 _nftId) public view override returns(address) {
        if (IPlanController(owner).isSubActive(_nftId)) {
            return(super.ownerOf(_nftId));
        } else {
            return(address(0));
        }
    }
    
    function interestOwnerOf(uint256 _nftId) public view returns(address) {
        return(super.ownerOf(_nftId));
    }
}
