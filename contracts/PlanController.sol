// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperTokenFactory.sol";
import { ISuperTokenFactory } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import "./SubscriptionNFT.sol";
import "./UserPool.sol";
import "./ProviderPool.sol";
import "./PToken.sol";

contract PlanController is Ownable {
    SubscriptionNFT public subNFT;
    address public userPool;
    address public providerPool;
    uint256 public period;
    ISuperTokenFactory superTokenFactory = ISuperTokenFactory(0x2C90719f25B10Fc5646c82DA3240C76Fa5BcCF34); // Check this address
    // address public provider; // Owner already exists from Ownable
    
    struct subToken {
        address pToken;     // Placeholder token
        address superToken;
        uint256 price;      // Price per period
        bool active;
    }
    
    struct subUser {
        address underlyingToken;
        uint256 startTimestamp;
    }
    
    mapping(address => subToken) public subTokens;
    mapping(uint256 => subUser) public subUsers;
    
    constructor(uint256 _period) {
        period = _period;
        subNFT = new SubscriptionNFT();
        userPool = address(new UserPool());
        providerPool = address(new ProviderPool());
        // provider = msg.sender;
    }
    
    function approveToken(address token, uint256 _price) public onlyOwner {
        require(token != address(0));
        require(!subTokens[token].active); // Require that this token has not already been approved
        // subTokens[token] = subToken(
        //     address(new PToken()))
        // address newSuperToken = address(superTokenFactory.createERC20Wrapper(token, 0, "name", "symbol"));
        address test = superTokenFactory.getHost();
        (bool success,) = address(superTokenFactory).call(abi.encode(bytes4(keccak256("getHost()"))));
        // superTokenFactory.createERC20Wrapper(token, 0, "name", "symbol");
        superTokenFactory.initializeCustomSuperToken(token);
        // subToken memory newSubToken = subToken(
        //     address(new PToken()), 
        //     address(superTokenFactory.createERC20Wrapper(token)), 
        //     _price, 
        //     true);
    }
    
    // function startSubscription(address token) public {
    //     require(subTokens[token].active);
        
    // }
    
}