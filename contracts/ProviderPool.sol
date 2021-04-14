// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol"; 

contract ProviderPool is Ownable {
    // Super pTokens will be streamed here. The 'super pToken' balance of this contract will be used to determine how many
    // aTokens from the userPool to convert back to underlyingTokens and transfer to the service provider. After the provider
    // cashes out, those super pTokens should be burned. (Or do they need to be downgraded to just pTokens and then burned?)
}