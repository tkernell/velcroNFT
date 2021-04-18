// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol"; 

interface ISuperToken {
    /**
     * @dev Destroys `amount` tokens from the caller's account, reducing the
     * total supply.
     *
     * If a send hook is registered for the caller, the corresponding function
     * will be called with `data` and empty `operatorData`. See {IERC777Sender}.
     *
     * Emits a {Burned} event.
     *
     * Requirements
     *
     * - the caller must have at least `amount` tokens.
     */
    function burn(uint256 amount, bytes calldata data) external;
}

// Super pTokens will be streamed here. The 'super pToken' balance of this contract will be used to determine how many
// aTokens from the userPool to convert back to underlyingTokens and transfer to the service provider. After the provider
// cashes out, those super pTokens should be burned. (Or do they need to be downgraded to just pTokens and then burned?)
contract ProviderPool is Ownable {
    function burnSuperToken(address superToken, uint256 amount) external onlyOwner {
        ISuperToken(superToken).burn(amount, "");
    }
}