// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

// import ""
import "./SubscriptionNFT.sol";
import "./UserPool.sol";
import "./ProviderPool.sol";

contract PlanController {
    address planFactory;
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
    
    constructor(uint256 _period, address _planFactory) {
        planFactory = _planFactory;
        period = _period;
        subNFT = new SubscriptionNFT(address(this));
        userPool = address(new UserPool());
        providerPool = address(new ProviderPool(address(this)));
    }
    
    function initialize(SubscriptionNFT _subNFT, address _userPool, address _providerPool, uint256 _period) public {
        subNFT = _subNFT;
        userPool = _userPool;
        providerPool = _providerPool;
        period = _period;
    }
    
    
    
    
}