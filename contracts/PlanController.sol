// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SubscriptionNFT.sol";
import "./UserPool.sol";
import "./ProviderPool.sol";
import "./PToken.sol";
import "./UserStreamWallet.sol";

contract ISuperTokenFactory {
    /**
     * @dev Upgradability modes
     */
    enum Upgradability {
        /// Non upgradable super token, `host.updateSuperTokenLogic` will revert
        NON_UPGRADABLE,
        /// Upgradable through `host.updateSuperTokenLogic` operation
        SEMI_UPGRADABLE,
        /// Always using the latest super token logic
        FULL_UPGRADABE
    }

    function createERC20Wrapper(
        IERC20 underlyingToken,
        uint8 underlyingDecimals,
        Upgradability upgradability,
        string calldata name,
        string calldata symbol
    ) public returns (ISuperToken superToken) {}
}

abstract contract ISuperToken {
    function transfer(address recipient, uint256 amount) virtual external returns (bool);
    /**
     * @dev Upgrade ERC20 to SuperToken.
     * @param amount Number of tokens to be upgraded (in 18 decimals)
     *
     * NOTE: It will use ´transferFrom´ to get tokens. Before calling this
     * function you should ´approve´ this contract
     */
    function upgrade(uint256 amount) virtual external;

    /**
     * @dev Upgrade ERC20 to SuperToken and transfer immediately
     * @param to The account to received upgraded tokens
     * @param amount Number of tokens to be upgraded (in 18 decimals)
     * @param data User data for the TokensRecipient callback
     *
     * NOTE: It will use ´transferFrom´ to get tokens. Before calling this
     * function you should ´approve´ this contract
     */
    function upgradeTo(address to, uint256 amount, bytes calldata data) virtual external;
}

contract PlanController is Ownable {
    SubscriptionNFT public subNFT;
    address public userPool;
    address public providerPool;
    uint256 public period;
    ISuperTokenFactory superTokenFactory = ISuperTokenFactory(0x2C90719f25B10Fc5646c82DA3240C76Fa5BcCF34); // Check this address
    IConstantFlowAgreementV1 constantFlowAgreement = IConstantFlowAgreementV1(address(0));
    
    struct subscriptionToken {
        PToken pToken;     // Placeholder token
        ISuperToken superToken;
        uint256 price;      // Price per period
        bool active;
    }
    
    struct subUser {
        address underlyingToken;
        uint256 startTimestamp;
        UserStreamWallet userStreamWallet;
    }
    
    mapping(address => subscriptionToken) public subscriptionTokens;
    // Mapping from NFT Token ID to subUser
    mapping(uint256 => subUser) public subUsers;
    
    modifier onlyNftOwner(uint256 _nftId) {
        require(msg.sender == subNFT.ownerOf(_nftId));
        _;
    }
    
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
        
        PToken newPToken = new PToken();
        ISuperToken newSuperPToken = superTokenFactory.createERC20Wrapper(
            IERC20(address(newPToken)),
            newPToken.decimals(),
            ISuperTokenFactory.Upgradability.NON_UPGRADABLE,
            "Super pToken",
            "pTKNx"
        );
        subscriptionTokens[_underlyingToken] = subscriptionToken(newPToken, newSuperPToken, _price, true);
    }
    
    // Mint NFT, mint pToken, upgrade pToken to pTokenX, stream pTokenX from userPool to providerPool, transfer underlyingToken from user,
    // convert underlyingToken to aToken and transfer to userPool, record parameters. Probably break this up into multiple transactions?
    // Also, add nonreentrancy protections?
    function createSubscription(address _underlyingToken) public returns(uint256) {
        require(subscriptionTokens[_underlyingToken].active);
        
        // Mint subscription NFT
        uint256 nftId = _initNewSubscriber(_underlyingToken);
        return(nftId);
    }
    
    function fundSubscription(uint256 nftId) public onlyNftOwner(nftId) {
        subUser memory newSubUser = subUsers[nftId];
        address underlyingToken = newSubUser.underlyingToken;
        subscriptionToken memory subToken = subscriptionTokens[underlyingToken]; 
        require(subToken.active);
        
        
        _initPTokens(subToken, nftId);
        
        // startStream(ISuperfluidToken _token, address _receiver, int96 _flowRate, bytes calldata _ctx)
        newSubUser.userStreamWallet.createStream(
            ISuperfluidToken(address(subToken.superToken)), 
            providerPool, 
            getFlowRate(underlyingToken), 
            ""
        );
        
        
        // Transfer 
    }
    
    function withdrawInterest(uint256 nftId) public onlyNftOwner(nftId) {
        
    }
    
    function _initNewSubscriber(address _underlyingToken) internal returns(uint256) {
        // Mint NFT
        uint256 nftId = subNFT.mint(msg.sender);
        // Generate new UserStreamWallet contract
        UserStreamWallet newUserStreamWallet = new UserStreamWallet(constantFlowAgreement);
        // Save subscriber parameters
        subUsers[nftId] = subUser(_underlyingToken, 0, newUserStreamWallet);
        return(nftId);
    }
    
    function _initPTokens(subscriptionToken memory subToken, uint256 nftId) internal {
        // Mint pTokens
        subToken.pToken.mint(address(this), subToken.price);
        // Approve transfer of pTokens by superToken contract
        subToken.pToken.approve(address(subToken.superToken), subToken.price);
        // Upgrade pTokens to super pTokens
        subToken.superToken.upgrade(subToken.price);
        subToken.superToken.transfer(address(subUsers[nftId].userStreamWallet), subToken.price);
    }
    

    function getFlowRate(address underlyingToken) public view returns(int96){
        return(int96(uint96(subscriptionTokens[underlyingToken].price/period)));
    }
}