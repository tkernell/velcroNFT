// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol"; 

interface ISuperToken {
    function burn(uint256 amount, bytes calldata data) external;
}

// Super pTokens will be streamed here. The 'super pToken' balance of this contract will be used to determine how many
// aTokens from the userPool to convert back to underlyingTokens and transfer to the service provider. After the provider
// cashes out, those super pTokens are burned
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