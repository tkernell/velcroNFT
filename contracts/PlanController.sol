// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    function treasury() external returns(address);
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
    address public provider;
    uint256 public period; // periodIndex
    ISuperTokenFactory superTokenFactory;
    IConstantFlowAgreementV1 constantFlowAgreement;
    // ILendingPool lendingPool;
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
    uint256[] public subscriptionDurations;
    uint256[] public availableSubscriptionDurationIndices;

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
    //  * @param _lendingPoolAddressProvider Aave lending pool address provider
    //  */
    function initialize(
        uint256 _period,
        address _provider,
        address _launcher,
        address _superTokenFactory,
        address _constantFlowAgreement,
        address _superfluidHost,
        address _lendingPoolAddressProvider
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
        lendingPoolAddressesProvider = ILendingPoolAddressesProviderV2(_lendingPoolAddressProvider);
    }

    /**
     * @dev Approve new subscription payment token, deploy needed placeholder token contracts
     * @param _underlyingToken Subscription payment token
     * @param _price Price of subscription
     */
    function approveToken(address _underlyingToken, uint256 _price) public onlyProvider {
        require(_underlyingToken != address(0));
        require(UserPool(userPool).isReserveActive(_underlyingToken));
        require(!subscriptionTokens[_underlyingToken].active);

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

    /**
     * @dev Remove subscription payment token
     * @param _underlyingToken Subscription payment token
     */
    function removeToken(address _underlyingToken) public onlyProvider {
        require(subscriptionTokens[_underlyingToken].active);
        subscriptionTokens[_underlyingToken].active = false;
    }

    /**
    * @dev Change subscription price per period for a given token
    * @param _underlyingToken Subscription payment token
    * @param _newPrice New price per subscription period
    */
    function updateSubscriptionPrice(address _underlyingToken, uint256 _newPrice) public onlyProvider {
        require(subscriptionTokens[_underlyingToken].active);
        require(_newPrice > 0);
        subscriptionTokens[_underlyingToken].price = _newPrice;
    }

    /**
     * @dev Set new subscription duration as number of periods
     * @param _numberOfPeriods Number of periods
     */
    function approveSubscriptionDuration(uint256 _numberOfPeriods) public onlyProvider {
        uint256 _indicesCount = availableSubscriptionDurationIndices.length;
        if (_indicesCount > 0) {
            subscriptionDurations[availableSubscriptionDurationIndices[_indicesCount-1]] = _numberOfPeriods;
            availableSubscriptionDurationIndices.pop();
        } else {
            subscriptionDurations.push(_numberOfPeriods);
        }
    }

    /**
     * @dev Remove subscription duration
     * @param _durationIndex Index of subscription duration in subscriptionDurations array
     */
    function removeSubscriptionDuration(uint256 _durationIndex) public onlyProvider {
        require(subscriptionDurations[_durationIndex] > 0);
        subscriptionDurations[_durationIndex] = 0;
        availableSubscriptionDurationIndices.push(_durationIndex);
    }

    // /**
    //  * @dev Initialize new subcription
    //  * @param _underlyingToken Subscription payment token
    //  */
    function createSubscription(address _underlyingToken) public returns(uint256) {
        require(subscriptionTokens[_underlyingToken].active);
        // require(subscriptionDurations[_durationIndex] > 0);

        // Mint subscription NFT
        uint256 _nftId = _initNewSubscriber(_underlyingToken);
        // subscriptionUsers[_nftId].initialDuration = subscriptionDurations[_durationIndex];

        emit SubscriptionCreated(msg.sender, _underlyingToken, _nftId);

        return(_nftId);
    }

    /**
     * @dev Pay for new subscription or refill existing subscription
     * @param _nftId ID of user's subscription NFT
     * @param _durationIndex Index of available subscription lengths array
     */
    function fundSubscription(uint256 _nftId, uint256 _durationIndex) public onlyNftOwner(_nftId) {
        subscriptionUser storage subUser = subscriptionUsers[_nftId];
        address underlyingToken = subUser.underlyingToken;
        require(subscriptionDurations[_durationIndex] > 0);
        subscriptionToken storage subToken = subscriptionTokens[underlyingToken];
        require(subToken.active);

        if(subUser.scaledBalance > 0) {
            rolloverInterest(_nftId);
        }

        uint256 _duration = subscriptionDurations[_durationIndex];
        uint256 feePct = planFactory.feePercentage();
        uint256 feeAmount = subToken.price * _duration * feePct / 10000;
        uint256 _realAmount = subToken.price * _duration - feeAmount;

        bool _isStreamActive = subToken.superToken.balanceOf(address(subUser.userStreamWallet)) > 0;
        // Mint, approve, upgrade, transfer pToken
        _initPTokens(subToken, _nftId, _realAmount);

        // if(subUser.scaledBalance > 0) {
        //     rolloverInterest(_nftId);
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
                subUser.endTimestamp = block.timestamp + period * _duration;
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
        IERC20(underlyingToken).transferFrom(msg.sender, planFactory.treasury(), feeAmount);
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
        console.log("Duration: %s", subUser.endTimestamp - subUser.startTimestamp);
    }

    /**
     * @dev Withdraw streamed funds
     * @param _underlyingToken Subscription payment token
     */
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
    //  * @dev Rollover interest
    //  * @param _nftId ID of subscription NFT to rollover
    //  */
    function rolloverInterest(uint256 _nftId) public onlyNftOwner(_nftId) {
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
        console.log("end: %s now: %s", subUser.endTimestamp, block.timestamp);
        uint256 interest;
        uint256 currentLiquidityIndex = ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(subUser.underlyingToken);
        bool expired;
        // If the subscription period has not ended...
        if (block.timestamp < subUser.endTimestamp) {
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - ((subUser.endTimestamp - time0) * (uint256(int256(getFlowRate(_nftId)))));
            console.log("Interest Case A");
            // adjustedScaledBalance = adjustedScaledBalance - interest.rayDiv(currentLiquidityIndex);
        // Else if the subscription period has ended and no principal remains...
        } else if (subToken.providerWithdrawalTimestamps.length > 0 && subToken.providerWithdrawalTimestamps[subToken.providerWithdrawalTimestamps.length - 1] > subUser.endTimestamp) {
            interest = currentLiquidityIndex.rayMul(adjustedScaledBalance - (subUser.endTimestamp - time0)*(uint256(int256(getFlowRate(_nftId)))).rayDiv(subToken.liquidityIndices[i]));
            // adjustedScaledBalance = 0;
            expired = true;
            console.log("Interest Case B");
        // Need another elseif for when user withdraws after endTimestamp, still some principal left, and user withdraws again
        } else {
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - (subUser.endTimestamp - time0)*(uint256(int256(getFlowRate(_nftId))));
            // adjustedScaledBalance = adjustedScaledBalance - interest.rayDiv(currentLiquidityIndex);
            console.log("Interest Case C");
        }

        // Get real interest to withdraw
        // uint256 pTokenSupply = IERC20(address(subToken.superToken)).totalSupply();
        // uint256 aTokenBalance = IERC20(UserPool(userPool).getReserveInterestToken(subUser.underlyingToken)).balanceOf(userPool);
        // uint256 globalInterest = subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - pTokenSupply;
        console.log("@USR_INT: %s", interest);
        console.log("@GLB_INT: %s", subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - IERC20(address(subToken.superToken)).totalSupply());
        console.log("@aTKN_BL: %s", (IERC20(UserPool(userPool).getReserveInterestToken(subUser.underlyingToken)).balanceOf(userPool)));
        console.log("@SPR_SPY: %s", IERC20(address(subToken.superToken)).totalSupply());
        console.log("@GLB_BAL: %s", subToken.globalScaledBalance.rayMul(currentLiquidityIndex));
        console.log("@USR_BAL: %s", adjustedScaledBalance.rayMul(currentLiquidityIndex));
        interest = interest * 5 / 10;
        uint256 realInterest = interest * (IERC20(UserPool(userPool).getReserveInterestToken(subUser.underlyingToken)).balanceOf(userPool) -
            IERC20(address(subToken.superToken)).totalSupply()) / (subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - IERC20(address(subToken.superToken)).totalSupply());
        uint256 keeperFee = realInterest * planFactory.keeperFeePercentage() / 10000;
        console.log("@RealInt: %s", realInterest);

        console.log("@KPR_FEE: %s", keeperFee);

        if(expired) {
            subscriptionUsers[_nftId].scaledBalance = 0;
        } else {
            subscriptionUsers[_nftId].scaledBalance = adjustedScaledBalance - getScaledBalance(subUser.underlyingToken, (realInterest * planFactory.keeperFeePercentage() / 10000));
        }

        subscriptionUsers[_nftId].startTimestamp = time0;
        subscriptionUsers[_nftId].endTimestamp += (realInterest-keeperFee) / (uint256(int256(getFlowRate(_nftId))));
        subscriptionUsers[_nftId].startLiquidityIndexArraySize = subToken.liquidityIndices.length;
        subscriptionTokens[subUser.underlyingToken].globalScaledBalance -= getScaledBalance(subUser.underlyingToken, (realInterest * planFactory.keeperFeePercentage() / 10000));
        UserPool(userPool).withdrawUnderlying(msg.sender, subUser.underlyingToken, keeperFee);

        subToken.pToken.mint(address(this), (realInterest-keeperFee));
        subToken.pToken.approve(address(subToken.superToken), realInterest-keeperFee);
        subToken.superToken.upgrade(realInterest-keeperFee);
        subToken.superToken.transfer(address(subUser.userStreamWallet), realInterest-keeperFee);

    }

    function isSubscriptionActive(uint256 _nftId) public view returns(bool) {
        return(block.timestamp < subscriptionUsers[_nftId].endTimestamp);
    }

    function deleteStream(uint256 _nftId) public onlyProvider {
        subscriptionUser memory subUser = subscriptionUsers[_nftId];
        subscriptionToken memory subToken = subscriptionTokens[subUser.underlyingToken];
        subUser.userStreamWallet.deleteStream(ISuperfluidToken(address(subToken.superToken)), address(providerPool));
    }

    function _initNewSubscriber(address _underlyingToken) internal returns(uint256) {
        uint256 nftId = subNFT.mint(msg.sender);
        UserStreamWallet newUserStreamWallet = new UserStreamWallet(constantFlowAgreement, superfluidHost);
        subscriptionUsers[nftId] = subscriptionUser(_underlyingToken, 0, 0, 0, 0, newUserStreamWallet, 0, 0);
        return(nftId);
    }

    function _initPTokens(subscriptionToken memory _subToken, uint256 _nftId, uint256 _realAmount) internal {
        _subToken.pToken.mint(address(this), _realAmount);
        _subToken.pToken.approve(address(_subToken.superToken), _realAmount);
        _subToken.superToken.upgrade(_realAmount);
        _subToken.superToken.transfer(address(subscriptionUsers[_nftId].userStreamWallet), _realAmount);
    }

    function getScaledBalance(address _underlyingToken, uint256 _amount) public view returns(uint256) {
        return(_amount.rayDiv(ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(_underlyingToken)));
    }

    function getFlowRate(uint256 _nftId) public view returns(int96){
        return(int96(uint96(subscriptionUsers[_nftId].realAmount / (period * subscriptionUsers[_nftId].initialDuration))));
    }

}
