// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

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
}
