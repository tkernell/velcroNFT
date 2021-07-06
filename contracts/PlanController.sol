// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./UserPool.sol";
import { ProviderPool } from "./ProviderPool.sol";
import "./PToken.sol";
import "./UserStreamWallet.sol";
import "./Aave/WadRayMath.sol";
import "./Aave/ILendingPoolAddressesProviderV2.sol";

import "hardhat/console.sol";

contract ISuperTokenFactory {
    enum Upgradability {
        NON_UPGRADABLE,
        SEMI_UPGRADABLE,
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

interface ISuperToken {
    function balanceOf(address account) external view returns(uint256 balance);
    function upgrade(uint256 amount) external;
    function transfer(address _to, uint256 _amount) external;
}

interface ILendingPool {
  function getReserveNormalizedIncome(address asset) external view returns (uint256);
}

interface ISubscriptionNFT {
    function mint(address _to) external returns(uint256);
    function interestOwnerOf(uint256 _nftId) external returns(address);
}

interface ILauncher {
    function firstLaunch() external returns(address);
}

interface IPlanFactory {
    function feePercentage() external returns(uint256);
    function keeperFeePercentage() external returns(uint256);
}

contract PlanController is Initializable {
    
    event SubscriptionCreated(address _user, address _token, uint256 _nftId);
    event SubscriptionFunded(address _user, address _token, uint256 _nftId);
    
    using WadRayMath for uint256;
    ISubscriptionNFT public subNFT;
    address public userPool;
    address public providerPool;
    IPlanFactory public planFactory;
    ILauncher public launcher;
    address public treasury;
    address public provider;
    uint256 public period; // periodIndex
    ISuperTokenFactory superTokenFactory;
    IConstantFlowAgreementV1 constantFlowAgreement;
    ILendingPool lendingPool;
    ILendingPoolAddressesProviderV2 lendingPoolAddressesProvider;
    ISuperfluid superfluidHost;


    struct subscriptionToken {
        PToken pToken;     // Placeholder token
        ISuperToken superToken;
        uint256 price;      // Price per period
        uint256[] liquidityIndices;
        uint256[] providerWithdrawalTimestamps;
        uint256 globalScaledBalance;
        bool active;
    }

    struct subscriptionUser {
        address underlyingToken;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 initialDuration;
        uint256 startLiquidityIndexArraySize;
        UserStreamWallet userStreamWallet;
        uint256 scaledBalance;
        uint256 realAmount;
    }

    mapping(address => subscriptionToken) public subscriptionTokens;
    // Mapping from NFT Token ID to Subscription User
    mapping(uint256 => subscriptionUser) public subscriptionUsers;
    uint256[] public subscriptionLengths;
    uint256[] public availableSubscriptionLengthIndices;

    modifier onlyNftOwner(uint256 _nftId) {
        require(msg.sender == subNFT.interestOwnerOf(_nftId));
        _;
    }
    
    modifier onlyProvider {
        require(msg.sender == provider);
        _;
    }
    
    // /**
    //  * @dev Initialized contract parameters and launches side contracts
    //  * @param _period Subscription period length in seconds
    //  * @param _provider Address of service provider
    //  * @param _launcher Address of external contract launcher
    //  * @param _superTokenFactory Superfluid token factory
    //  * @param _constantFlowAgreement Superfluid constant flow agreement
    //  * @param _superfluidHost Superfluid contract
    //  * @param _lendingPool Aave lending pool contract
    //  * @param _lendingPoolAddressProvider Aave lending pool address provider
    //  * @param _treasury VelcroNFT treasury
    //  */
    function initialize(
        uint256 _period, 
        address _provider, 
        address _launcher, 
        address _superTokenFactory, 
        address _constantFlowAgreement, 
        address _superfluidHost,
        address _lendingPool,
        address _lendingPoolAddressProvider,
        address _treasury
        ) public initializer {
            
        launcher = ILauncher(_launcher);
        period = _period;
        subNFT = ISubscriptionNFT(launcher.firstLaunch());
        userPool = address(new UserPool());
        providerPool = address(new ProviderPool());
        provider = _provider;
        planFactory = IPlanFactory(msg.sender);
        superTokenFactory = ISuperTokenFactory(_superTokenFactory);
        constantFlowAgreement = IConstantFlowAgreementV1(_constantFlowAgreement);
        superfluidHost = ISuperfluid(_superfluidHost);
        lendingPool = ILendingPool(_lendingPool);
        lendingPoolAddressesProvider = ILendingPoolAddressesProviderV2(_lendingPoolAddressProvider);
        treasury = _treasury;
    }

    // /**
    //  * @dev Approve new subscription payment token, deploy needed placeholder token contracts
    //  * @param _underlyingToken Subscription payment token 
    //  * @param _price Price of subscription
    //  */
    function approveToken(address _underlyingToken, uint256 _price) public onlyProvider {
        require(_underlyingToken != address(0));
        require(UserPool(userPool).isReserveActive(_underlyingToken));
        require(!subscriptionTokens[_underlyingToken].active); // Require that this token has not already been approved

        PToken newPToken = new PToken();
        ISuperToken newSuperPToken = superTokenFactory.createERC20Wrapper(
            IERC20(address(newPToken)),
            newPToken.decimals(),
            ISuperTokenFactory.Upgradability.NON_UPGRADABLE,
            "Super pToken",
            "pTKNx"
        );
        subscriptionTokens[_underlyingToken] = subscriptionToken(
            newPToken,
            newSuperPToken,
            _price,
            new uint[](0),
            new uint[](0),
            0,
            true);
    }
    
    // /**
    //  * @dev Remove subscription payment token
    //  * @param _underlyingToken Subscription payment token 
    //  */
    function removeToken(address _underlyingToken) public onlyProvider {
        require(subscriptionTokens[_underlyingToken].active);
        subscriptionTokens[_underlyingToken].active = false;
    }
    
    function approveSubscriptionLength(uint256 _length) public onlyProvider {
        uint256 _indicesCount = availableSubscriptionLengthIndices.length;
        if (_indicesCount > 0) {
            subscriptionLengths[availableSubscriptionLengthIndices[_indicesCount-1]] = _length;
            availableSubscriptionLengthIndices.pop();
        } else {
            subscriptionLengths.push(_length);
        }
    }
    
    function removeSubscriptionLength(uint256 _lengthIndex) public onlyProvider {
        require(subscriptionLengths[_lengthIndex] > 0);
        subscriptionLengths[_lengthIndex] = 0;
        availableSubscriptionLengthIndices.push(_lengthIndex);
    }

    // /**
    //  * @dev Initialize new subcription
    //  * @param _underlyingToken Subscription payment token 
    //  */
    function createSubscription(address _underlyingToken) public returns(uint256) {
        require(subscriptionTokens[_underlyingToken].active);
        // require(subscriptionLengths[_durationIndex] > 0);

        // Mint subscription NFT
        uint256 _nftId = _initNewSubscriber(_underlyingToken);
        // subscriptionUsers[_nftId].initialDuration = subscriptionLengths[_durationIndex];
        
        emit SubscriptionCreated(msg.sender, _underlyingToken, _nftId);
        
        return(_nftId);
    }
    
    // /**
    //  * @dev Pay for subscription and start immediately
    //  * @param _nftId ID of user's subscription NFT
    //  */
    // function fundSubscription(uint256 _nftId, uint256 _durationIndex) public onlyNftOwner(_nftId) {
    //     require(subscriptionLengths[_durationIndex] > 0);
    //     subscriptionUser memory subUser = subscriptionUsers[_nftId];
    //     address underlyingToken = subUser.underlyingToken;
    //     subscriptionToken memory subToken = subscriptionTokens[underlyingToken];
    //     require(subToken.active, "PlanController: token not approved");
        
    //     subscriptionUsers[_nftId].initialDuration = subscriptionLengths[_durationIndex];
    //     uint256 feePct = planFactory.feePercentage();
    //     uint256 feeAmount = subToken.price * subUser.initialDuration * feePct / 10000;
    //     uint256 _realAmount = subToken.price * subscriptionUsers[_nftId].initialDuration - feeAmount;
        
    //     subscriptionUsers[_nftId].realAmount = _realAmount;

    //     // Mint, approve, upgrade, transfer pToken
    //     _initPTokens(subToken, _nftId, _realAmount);
    //     console.log("#FLW_RAT: %s", (uint256(int256(getFlowRate(_nftId)))));
    //     // start Superfluid Stream
    //     subUser.userStreamWallet.createStream(
    //         ISuperfluidToken(address(subToken.superToken)),
    //         providerPool,
    //         getFlowRate(_nftId)
    //     );

    //     // Transfer underlying token from user to userPool
    //     IERC20(underlyingToken).transferFrom(msg.sender, address(userPool), _realAmount);
    //     // Transfer fee to treasury
    //     IERC20(underlyingToken).transferFrom(msg.sender, treasury, feeAmount);
    //     // Convert underlying token to aToken through userPool
    //     UserPool(userPool).depositUnderlying(underlyingToken, _realAmount);
    //     // Record scaled balance
    //     subscriptionUsers[_nftId].scaledBalance = getScaledBalance(underlyingToken, _realAmount);
    //     // Record subscription start timestamp
    //     subscriptionUsers[_nftId].startTimestamp = block.timestamp;
    //     // Record subscription end timestamp
    //     subscriptionUsers[_nftId].endTimestamp = block.timestamp + period * subUser.initialDuration;
    //     // Record liquidityIndices array size
    //     subscriptionUsers[_nftId].startLiquidityIndexArraySize = subToken.liquidityIndices.length;
    //     // Add user's scaled balance to global scaled balance
    //     subscriptionTokens[underlyingToken].globalScaledBalance += subscriptionUsers[_nftId].scaledBalance;
    // }
    
    function fundSubscription(uint256 _nftId, uint256 _durationIndex) public onlyNftOwner(_nftId) {
        subscriptionUser storage subUser = subscriptionUsers[_nftId];
        address underlyingToken = subUser.underlyingToken;
        require(subscriptionLengths[_durationIndex] > 0);
        subscriptionToken storage subToken = subscriptionTokens[underlyingToken];
        require(subToken.active);
        
        uint256 _duration = subscriptionLengths[_durationIndex];
        uint256 feePct = planFactory.feePercentage();
        uint256 feeAmount = subToken.price * _duration * feePct / 10000;
        uint256 _realAmount = subToken.price * _duration - feeAmount;
        
        bool _isStreamActive = subToken.superToken.balanceOf(address(subUser.userStreamWallet)) > 0;
        // Mint, approve, upgrade, transfer pToken
        _initPTokens(subToken, _nftId, _realAmount);
        
        if(subUser.scaledBalance > 0) {
            withdrawInterest(_nftId);
            // subUser.realAmount += _realAmount;
        } 
        // else {
        //     subUser.realAmount = _realAmount;
        //     subUser.startTimestamp = block.timestamp;
        //     subUser.endTimestamp = block.timestamp;
        //     subUser.initialDuration = _duration;
            
        //     subUser.userStreamWallet.createStream(
        //         ISuperfluidToken(address(subToken.superToken)),
        //         providerPool,
        //         getFlowRate(_nftId)
        //     );
        // }
        
        if(_isStreamActive) {
            subUser.initialDuration += _duration;
            subUser.realAmount += _realAmount;
            subUser.endTimestamp += period * _duration;
            
            subUser.userStreamWallet.updateStream(
                ISuperfluidToken(address(subToken.superToken)),
                providerPool,
                getFlowRate(_nftId)
            );
        } else {
            if(block.timestamp < subUser.endTimestamp) {
                subUser.endTimestamp += period * _duration;
            } else {
                subUser.endTimestamp = block.timestamp;
            }
            subUser.initialDuration = _duration;
            subUser.realAmount = _realAmount;
            
            subUser.userStreamWallet.createStream(
                ISuperfluidToken(address(subToken.superToken)),
                providerPool,
                getFlowRate(_nftId)
            );
        }
        
        // Transfer underlying token from user to userPool
        IERC20(underlyingToken).transferFrom(msg.sender, address(userPool), _realAmount);
        // Transfer fee to treasury
        IERC20(underlyingToken).transferFrom(msg.sender, treasury, feeAmount);
        // Convert underlying token to aToken through userPool
        UserPool(userPool).depositUnderlying(underlyingToken, _realAmount);
        // Record scaled balance
        subUser.scaledBalance += getScaledBalance(underlyingToken, _realAmount);
        // Record subscription start timestamp
        subscriptionUsers[_nftId].startTimestamp = block.timestamp;
        // Record subscription end timestamp
        // subUser.endTimestamp += period * subUser.initialDuration;
        // Record liquidityIndices array size
        subUser.startLiquidityIndexArraySize = subToken.liquidityIndices.length;
        // Add user's scaled balance to global scaled balance
        subToken.globalScaledBalance += getScaledBalance(underlyingToken, _realAmount);
    }
    
    // /**
    //  * @dev Withdraw streamed funds
    //  * @param _underlyingToken Subscription payment token 
    //  */
    function providerWithdrawal(address _underlyingToken) public onlyProvider {
        // Amount = super pToken balance of providerPool
        uint256 amount = subscriptionTokens[_underlyingToken].superToken.balanceOf(providerPool);
        // console.log("@PRW_AMT: %s", amount);
        // Convert 'amount' of aTokens from userPool back to underlyingToken
        // Send 'amount' to provider (owner)
        UserPool(userPool).withdrawUnderlying(provider, _underlyingToken, amount);
        // Push liquidityIndex from Aave lendingPool.getReserveNormalizedIncome to subscriptionTokens[_underlyingToken].liquidityIndices
        subscriptionTokens[_underlyingToken].liquidityIndices.push(ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(_underlyingToken));
        // Push block timestamp to subscriptionTokens[_underlyingToken].providerWithdrawalTimestamps
        subscriptionTokens[_underlyingToken].providerWithdrawalTimestamps.push(block.timestamp);
        // Burn Super pTokens from providerPool
        ProviderPool(providerPool).burnSuperToken(address(subscriptionTokens[_underlyingToken].superToken), amount);
        // Subtract withdrawal amount from global scaled balance
        subscriptionTokens[_underlyingToken].globalScaledBalance -= getScaledBalance(_underlyingToken, amount);
    }
    
    // /**
    //  * @dev Withdraw streamed funds
    //  * @param _nftId ID of user's subscription NFT
    //  */
    function withdrawInterest(uint256 _nftId) public onlyNftOwner(_nftId) {
        subscriptionUser memory subUser = subscriptionUsers[_nftId];
        subscriptionToken memory subToken = subscriptionTokens[subUser.underlyingToken];
        require(subUser.scaledBalance > 0);
        
        uint256 adjustedScaledBalance = subUser.scaledBalance;
        uint256 i = subUser.startLiquidityIndexArraySize;
        uint256 time0 = subUser.startTimestamp;
        while (i < subToken.liquidityIndices.length && subToken.providerWithdrawalTimestamps[i] <= subUser.endTimestamp) {
            uint256 time1 = subToken.providerWithdrawalTimestamps[i];
            adjustedScaledBalance = adjustedScaledBalance - (time1 - time0) * (uint256(int256(getFlowRate(_nftId)))).rayDiv(subToken.liquidityIndices[i]);
            time0 = time1;
            i++;
        }
        
        uint256 interest;
        uint256 currentLiquidityIndex = ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(subUser.underlyingToken);
        // If the subscription period has not ended...
        if (block.timestamp < subUser.endTimestamp) {
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - ((subUser.endTimestamp - time0) * (uint256(int256(getFlowRate(_nftId)))));
            console.log("Interest calculated: %s", interest);
            // adjustedScaledBalance = adjustedScaledBalance - interest.rayDiv(currentLiquidityIndex);
        // Else if the subscription period has ended and no principal remains...
        } else if (subToken.providerWithdrawalTimestamps.length > 0 && subToken.providerWithdrawalTimestamps[subToken.providerWithdrawalTimestamps.length - 1] > subUser.endTimestamp) {
            interest = currentLiquidityIndex.rayMul(adjustedScaledBalance - (subUser.endTimestamp - time0)*(uint256(int256(getFlowRate(_nftId)))).rayDiv(subToken.liquidityIndices[i]));
            // adjustedScaledBalance = 0;
        // Need another elseif for when user withdraws after endTimestamp, still some principal left, and user withdraws again
        } else {
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - (subUser.endTimestamp - time0)*(uint256(int256(getFlowRate(_nftId))));
            // adjustedScaledBalance = adjustedScaledBalance - interest.rayDiv(currentLiquidityIndex);
        }
        
        // Get real interest to withdraw
        // uint256 pTokenSupply = IERC20(address(subToken.superToken)).totalSupply();
        // uint256 aTokenBalance = IERC20(UserPool(userPool).getReserveInterestToken(subUser.underlyingToken)).balanceOf(userPool);
        // uint256 globalInterest = subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - pTokenSupply;
        console.log("@USR_INT: %s", interest);
        // console.log("@aTKN_BL: %s", (IERC20(UserPool(userPool).getReserveInterestToken(subUser.underlyingToken)).balanceOf(userPool)));
        // console.log("@SPR_SPY: %s", IERC20(address(subToken.superToken)).totalSupply());
        uint256 realInterest = interest * (IERC20(UserPool(userPool).getReserveInterestToken(subUser.underlyingToken)).balanceOf(userPool) - 
            IERC20(address(subToken.superToken)).totalSupply()) / (subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - IERC20(address(subToken.superToken)).totalSupply());
        uint256 keeperFee = realInterest * planFactory.keeperFeePercentage() / 10000;
        // console.log("@RealInt: %s", realInterest);
        
        // console.log("@GLB_SBL: %s", subscriptionTokens[subUser.underlyingToken].globalScaledBalance);
        // console.log("@USR_SBL: %s", adjustedScaledBalance);
        // console.log("@KPR_FEE: %s", keeperFee);
        
        subscriptionUsers[_nftId].scaledBalance = adjustedScaledBalance - getScaledBalance(subUser.underlyingToken, interest * planFactory.keeperFeePercentage() / 10000);
        subscriptionUsers[_nftId].startTimestamp = time0;
        subscriptionUsers[_nftId].endTimestamp += (realInterest-keeperFee) / (uint256(int256(getFlowRate(_nftId))));
        subscriptionUsers[_nftId].startLiquidityIndexArraySize = subToken.liquidityIndices.length;
        subscriptionTokens[subUser.underlyingToken].globalScaledBalance -= getScaledBalance(subUser.underlyingToken, interest * planFactory.keeperFeePercentage() / 10000);
        UserPool(userPool).withdrawUnderlying(msg.sender, subUser.underlyingToken, keeperFee);
        
        subToken.pToken.mint(address(this), realInterest-keeperFee);
        subToken.pToken.approve(address(subToken.superToken), realInterest-keeperFee);
        subToken.superToken.upgrade(realInterest-keeperFee);
        subToken.superToken.transfer(address(subUser.userStreamWallet), realInterest-keeperFee);
        // console.log("@EXT_TME: %s", (realInterest-keeperFee) / (uint256(int256(getFlowRate(_nftId)))));
        // console.log("@FLW_RAT: %s", (uint256(int256(getFlowRate(_nftId)))));
        // console.log("@REALAMT: %s", subUser.realAmount);
        // console.log("@PERIOD : %s", period);
    }

    function isSubscriptionActive(uint256 _nftId) public view returns(bool) {
        return(block.timestamp < subscriptionUsers[_nftId].endTimestamp);
    }

    function deleteStream(uint256 _nftId) public onlyProvider {
        subscriptionUser memory subUser = subscriptionUsers[_nftId];
        subscriptionToken memory subToken = subscriptionTokens[subUser.underlyingToken];
        subUser.userStreamWallet.deleteStream(ISuperfluidToken(address(subToken.superToken)), address(providerPool));
    }

    function viewIndicesAndTimestamps(address _underlyingToken, uint256 _index) public view returns(uint256 liquidityIndex, uint256 timestamp) {
        return(subscriptionTokens[_underlyingToken].liquidityIndices[_index], subscriptionTokens[_underlyingToken].providerWithdrawalTimestamps[_index]);
    }

    function tokenIsActive(address _underlyingToken) public view returns(bool) {
        return(subscriptionTokens[_underlyingToken].active);
    }

    function _initNewSubscriber(address _underlyingToken) internal returns(uint256) {
        // Mint NFT
        uint256 nftId = subNFT.mint(msg.sender);
        // Generate new UserStreamWallet contract
        UserStreamWallet newUserStreamWallet = new UserStreamWallet(constantFlowAgreement, superfluidHost);
        // Save subscriber parameters
        subscriptionUsers[nftId] = subscriptionUser(_underlyingToken, 0, 0, 0, 0, newUserStreamWallet, 0, 0);
        return(nftId);
    }

    function _initPTokens(subscriptionToken memory _subToken, uint256 _nftId, uint256 _realAmount) internal {
        // Mint pTokens
        _subToken.pToken.mint(address(this), _realAmount);
        // Approve transfer of pTokens by superToken contract
        _subToken.pToken.approve(address(_subToken.superToken), _realAmount);
        // Upgrade pTokens to super pTokens
        // subToken.superToken.upgradeTo(address(subUsers[nftId].userStreamWallet), realAmount, '');
        _subToken.superToken.upgrade(_realAmount);
        // Transfer super pTokens to userStreamWallet
        _subToken.superToken.transfer(address(subscriptionUsers[_nftId].userStreamWallet), _realAmount);
    }

    function getScaledBalance(address _underlyingToken, uint256 _amount) public view returns(uint256) {
        return(_amount.rayDiv(ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(_underlyingToken)));
    }

    function getFlowRate(uint256 _nftId) public view returns(int96){
        return(int96(uint96(subscriptionUsers[_nftId].realAmount / (period * subscriptionUsers[_nftId].initialDuration))));
    }
    
    // function testDepositExtra(address underlyingToken, uint256 amount) external {
    //     IERC20(underlyingToken).transferFrom(msg.sender, address(userPool), amount);
    //     UserPool(userPool).depositUnderlying(underlyingToken, amount);
    // }
    
}
