// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperTokenFactory.sol";
import { ISuperTokenFactory } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
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
    
    struct subscriptionToken {
        PToken pToken;     // Placeholder token
        ISuperToken superToken;
        uint256 price;      // Price per period
        bool active;
    }
    
    struct subUser {
        address underlyingToken;
        uint256 startTimestamp;
    }
    
    mapping(address => subscriptionToken) public subscriptionTokens;
    // Mapping from NFT Token ID to subUser
    mapping(uint256 => subUser) public subUsers;
    
    constructor(uint256 _period) {
        period = _period;
        subNFT = new SubscriptionNFT();
        userPool = address(new UserPool());
        providerPool = address(new ProviderPool());
        // provider = msg.sender;
    }
    
    // After checks, create new PToken contract and new SuperToken contract.
    function approveToken(address _underlyingToken, uint256 _price) public onlyOwner {
        require(_underlyingToken != address(0));
        require(!subscriptionTokens[_underlyingToken].active); // Require that this token has not already been approved
        // subTokens[token] = subToken(
        //     address(new PToken()))
        address newSuperToken = address(superTokenFactory.createERC20Wrapper(_underlyingToken, 0, "name", "symbol"));
        address test = superTokenFactory.getHost();
        (bool success,) = address(superTokenFactory).call(abi.encode(bytes4(keccak256("getHost()"))));
        // superTokenFactory.createERC20Wrapper(token, 0, "name", "symbol");
        superTokenFactory.initializeCustomSuperToken(_underlyingToken);
        // subToken memory newSubToken = subToken(
        //     address(new PToken()), 
        //     address(superTokenFactory.createERC20Wrapper(token)), 
        //     _price, 
        //     true);
    }
    
    // Mint NFT, mint pToken, upgrade pToken to pTokenX, stream pTokenX from userPool to providerPool, transfer underlyingToken from user,
    // convert underlyingToken to aToken and transfer to userPool, record parameters. Probably break this up into multiple transactions?
    // Also, add nonreentrancy protections?
    function createSubscription(address _underlyingToken) public {
        require(subscriptionTokens[_underlyingToken].active);
        
        uint256 nftID = subNFT.mint(msg.sender);
        subUsers[nftID] = subUser(_underlyingToken, block.timestamp);
        subscriptionToken memory subToken = subscriptionTokens[_underlyingToken]; 
        subToken.pToken.mint(address(this), subToken.price);
        subToken.superToken.upgrade(subToken.price);
        subToken.superToken.transfer(userPool, subToken.price);
        
    }
    
    function withdrawInterest() public {
        
    }
    
    
    
}