// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SubscriptionNFT is ERC721Upgradeable, OwnableUpgradeable {
    uint256 counter;

    function initialize() public initializer {
        __ERC721_init("Velcro NFT Subscription", "VEL");
    }

    function mint(address _to) public onlyOwner returns(uint256) {
        _mint(_to, counter);
        counter++;
        return(counter-1);
    }
}
