// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SubscriptionNFT is ERC721 {
    address owner;
    uint256 counter;
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    constructor(address _owner) ERC721("Subscription", "SUB") {
        owner = _owner;
    }
    
    function mint(address _to) public onlyOwner {
        _mint(_to, counter);
        counter++;
    }
}