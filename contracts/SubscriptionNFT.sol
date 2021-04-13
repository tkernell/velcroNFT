// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SubscriptionNFT is ERC721, Ownable {
    uint256 counter;
    
    constructor() ERC721("Velcro NFT Subsription", "VEL") {}
    
    function mint(address _to) public onlyOwner returns(uint256) {
        _mint(_to, counter);
        counter++;
        return(counter-1);
    }
}