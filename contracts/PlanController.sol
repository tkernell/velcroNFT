// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "./SubscriptionNFT.sol";

contract PlanController {
    SubscriptionNFT subNFT;
    address userPool;
    address providerPool;
    uint256 period;
    
    struct subToken {
        address pToken;
        address superToken;
        bool active;
    }
    
    mapping(address => subToken) subTokens;
    
    constructor(SubscriptionNFT _subNFT, address _userPool, address _providerPool, uint256 _period) {
        subNFT = _subNFT;
        userPool = _userPool;
        providerPool = _providerPool;
        period = _period;
    }
    
    
    
    
}