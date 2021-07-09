// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol"; 

interface ISuperToken {
    function burn(uint256 amount, bytes calldata data) external;
}

contract ProviderPool is Ownable {
    
    /**
     * @dev Burn SuperPTokens
     * @param superToken Address of SuperPToken
     * @param amount How much to burn
     */
    function burnSuperToken(address superToken, uint256 amount) external onlyOwner {
        ISuperToken(superToken).burn(amount, "");
    }
}