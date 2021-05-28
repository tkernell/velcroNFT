// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./UserPool.sol";
import { ProviderPool } from "./ProviderPool.sol";
import "./PToken.sol";
import "./UserStreamWallet.sol";
import "./Aave/WadRayMath.sol";
import "./Aave/ILendingPoolAddressesProviderV2.sol";

// import "hardhat/console.sol";

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

abstract contract ISuperToken {
    function balanceOf(address account) virtual external view returns(uint256 balance);
    function upgrade(uint256 amount) virtual external;
    function transfer(address _to, uint256 _amount) virtual external;
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
}

contract PlanController is Initializable {
    using WadRayMath for uint256;
    ISubscriptionNFT public subNFT;
    address public userPool;
    address public providerPool;
    IPlanFactory public planFactory;
    ILauncher public launcher;
    address public treasury;
    address public owner;
    uint256 public period;
    // SuperTokenFactory on Matic: 0x2C90719f25B10Fc5646c82DA3240C76Fa5BcCF34
    // SuperTokenFactory on Kovan: 0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561
    // ISuperTokenFactory superTokenFactory = ISuperTokenFactory(0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561);
    ISuperTokenFactory superTokenFactory;
    // ConstantFlowAgreementV1 on Matic: 0x6EeE6060f715257b970700bc2656De21dEdF074C
    // ConstantFlowAgreementV1 on Kovan: 0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F
    // IConstantFlowAgreementV1 constantFlowAgreement = IConstantFlowAgreementV1(0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F);
    IConstantFlowAgreementV1 constantFlowAgreement;
    // Aave LendingPool on Matic: 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf
    // Aave LendingPool on Kovan: 0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe
    // ILendingPool lendingPool = ILendingPool(0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe);
    ILendingPool lendingPool;
    // Aave LendingPoolAddressesProviderV2 on Matic: 0xd05e3E715d945B59290df0ae8eF85c1BdB684744
    // Aave LendingPoolAddressesProviderV2 on Kovan: 0x88757f2f99175387aB4C6a4b3067c77A695b0349
    // ILendingPoolAddressesProviderV2 lendingPoolAddressesProvider = ILendingPoolAddressesProviderV2(0x88757f2f99175387aB4C6a4b3067c77A695b0349);
    ILendingPoolAddressesProviderV2 lendingPoolAddressesProvider;
    // Superfluid host on Matic:
    // Superfluid host on Kovan: 0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3
    // ISuperfluid superfluidHost = ISuperfluid(0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3);
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

    struct subUser {
        address underlyingToken;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 startLiquidityIndexArraySize;
        UserStreamWallet userStreamWallet;
        uint256 scaledBalance;
        uint256 realAmount;
    }

    mapping(address => subscriptionToken) public subscriptionTokens;
    // Mapping from NFT Token ID to subUser
    mapping(uint256 => subUser) public subUsers;

    modifier onlyNftOwner(uint256 _nftId) {
        require(msg.sender == subNFT.interestOwnerOf(_nftId));
        _;
    }
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function initialize(
        uint256 _periodDays, 
        address _owner, 
        address _launcher, 
        address _superTokenFactory, 
        address _constantFlowAgreement, 
        address _superfluidHost,
        address _lendingPool,
        address _lendingPoolAddressProvider,
        address _treasury
        ) public initializer {
            
        launcher = ILauncher(_launcher);
        period = _periodDays * 1 days;
        subNFT = ISubscriptionNFT(launcher.firstLaunch());
        userPool = address(new UserPool());
        providerPool = address(new ProviderPool());
        owner = _owner;
        planFactory = IPlanFactory(msg.sender);
        superTokenFactory = ISuperTokenFactory(_superTokenFactory);
        constantFlowAgreement = IConstantFlowAgreementV1(_constantFlowAgreement);
        superfluidHost = ISuperfluid(_superfluidHost);
        lendingPool = ILendingPool(_lendingPool);
        lendingPoolAddressesProvider = ILendingPoolAddressesProviderV2(_lendingPoolAddressProvider);
        treasury = _treasury;
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
        subscriptionTokens[_underlyingToken] = subscriptionToken(
            newPToken,
            newSuperPToken,
            _price,
            new uint[](0),
            new uint[](0),
            0,
            true);
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
        require(subToken.active, "PlanController: token not approved");
        
        // TESTING FEE
        uint256 feePct = planFactory.feePercentage();
        uint256 feeAmount = subToken.price * feePct / 10000;
        uint256 _realAmount = subToken.price - feeAmount;
        
        subUsers[nftId].realAmount = _realAmount;

        // Mint, approve, upgrade, transfer pToken
        _initPTokens(subToken, nftId, _realAmount);

        // start Superfluid Stream
        newSubUser.userStreamWallet.createStream(
            ISuperfluidToken(address(subToken.superToken)),
            providerPool,
            getFlowRate(nftId)
        );

        // Transfer underlying token from user to userPool
        IERC20(underlyingToken).transferFrom(msg.sender, address(userPool), _realAmount);
        // Transfer fee to treasury
        IERC20(underlyingToken).transferFrom(msg.sender, treasury, feeAmount);
        // Convert underlying token to aToken through userPool
        UserPool(userPool).depositUnderlying(underlyingToken, _realAmount);
        // Record scaled balance
        subUsers[nftId].scaledBalance = getScaledBalance(underlyingToken, _realAmount);
        // Record subscription start timestamp
        subUsers[nftId].startTimestamp = block.timestamp;
        // Record subscription end timestamp
        subUsers[nftId].endTimestamp = block.timestamp + period;
        // Record liquidityIndices array size
        subUsers[nftId].startLiquidityIndexArraySize = subToken.liquidityIndices.length;
        // Add user's scaled balance to global scaled balance
        subscriptionTokens[underlyingToken].globalScaledBalance += subUsers[nftId].scaledBalance;
        // Record real amount after fee
        // subUsers[nftId].realAmount = _realAmount;
    }

    function providerWithdrawal(address _underlyingToken) public onlyOwner {
        // Amount = super pToken balance of providerPool
        uint256 amount = subscriptionTokens[_underlyingToken].superToken.balanceOf(providerPool);
        // console.log("@PRW_AMT: %s", amount);
        // Convert 'amount' of aTokens from userPool back to underlyingToken
        // Send 'amount' to provider (owner)
        UserPool(userPool).withdrawUnderlying(owner, _underlyingToken, amount);
        // Push liquidityIndex from Aave lendingPool.getReserveNormalizedIncome to subscriptionTokens[_underlyingToken].liquidityIndices
        subscriptionTokens[_underlyingToken].liquidityIndices.push(ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(_underlyingToken));
        // Push block timestamp to subscriptionTokens[_underlyingToken].providerWithdrawalTimestamps
        subscriptionTokens[_underlyingToken].providerWithdrawalTimestamps.push(block.timestamp);
        // Burn Super pTokens from providerPool
        ProviderPool(providerPool).burnSuperToken(address(subscriptionTokens[_underlyingToken].superToken), amount);
        // Subtract withdrawal amount from global scaled balance
        subscriptionTokens[_underlyingToken].globalScaledBalance -= getScaledBalance(_underlyingToken, amount);
    }

    function withdrawInterest(uint256 nftId) public onlyNftOwner(nftId) {
        subUser memory thisSubUser = subUsers[nftId];
        subscriptionToken memory subToken = subscriptionTokens[thisSubUser.underlyingToken];
        require(thisSubUser.scaledBalance > 0);
        
        // console.log("Alpha");

        uint256 adjustedScaledBalance = thisSubUser.scaledBalance;
        uint256 i = thisSubUser.startLiquidityIndexArraySize;
        uint256 time0 = thisSubUser.startTimestamp;
        while (i < subToken.liquidityIndices.length && subToken.providerWithdrawalTimestamps[i] <= thisSubUser.endTimestamp) {
            uint256 time1 = subToken.providerWithdrawalTimestamps[i];
            adjustedScaledBalance = adjustedScaledBalance - (time1 - time0) * (uint256(int256(getFlowRate(nftId)))).rayDiv(subToken.liquidityIndices[i]);
            time0 = time1;
            i += 1;
        }
        
        // console.log("Beta");

        uint256 interest;
        uint256 currentLiquidityIndex = ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(thisSubUser.underlyingToken);
        // If the subscription period has not ended...
        if (block.timestamp < thisSubUser.endTimestamp) {
            // interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - subToken.superToken.balanceOf(address(thisSubUser.userStreamWallet));
            // console.log("Sub not ended");
            // console.log(adjustedScaledBalance.rayMul(currentLiquidityIndex));
            // console.log((thisSubUser.endTimestamp - time0 + 1));
            // console.log((uint256(int256(getFlowRate(nftId)))));
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - ((thisSubUser.endTimestamp - time0) * (uint256(int256(getFlowRate(nftId)))));
            // console.log("Interest calculated: %s", interest);
            adjustedScaledBalance = adjustedScaledBalance - interest.rayDiv(currentLiquidityIndex);
        // Else if the subscription period has ended and no principal remains...
        } else if (subToken.providerWithdrawalTimestamps.length > 0 && subToken.providerWithdrawalTimestamps[subToken.providerWithdrawalTimestamps.length - 1] > thisSubUser.endTimestamp) {
            interest = currentLiquidityIndex.rayMul(adjustedScaledBalance - (thisSubUser.endTimestamp - time0)*(uint256(int256(getFlowRate(nftId)))).rayDiv(subToken.liquidityIndices[i]));
            adjustedScaledBalance = 0;
        // Need another elseif for when user withdraws after endTimestamp, still some principal left, and user withdraws again
        } else {
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - (thisSubUser.endTimestamp - time0)*(uint256(int256(getFlowRate(nftId))));
            adjustedScaledBalance = adjustedScaledBalance - interest.rayDiv(currentLiquidityIndex);
        }
        
        // console.log("Gamma");
        
        // Get real interest to withdraw
        uint256 pTokenSupply = IERC20(address(subToken.superToken)).totalSupply();
        uint256 aTokenBalance = IERC20(UserPool(userPool).getReserveInterestToken(thisSubUser.underlyingToken)).balanceOf(userPool);
        // uint256 globalInterest = subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - pTokenSupply;
        uint256 realInterest = interest * (aTokenBalance - pTokenSupply) / (subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - pTokenSupply);
        // console.log("@RealInt: %s", realInterest);
        // console.log("@GLB_INT: %s", subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - pTokenSupply);
        // console.log("@USR_INT: %s", interest);
        // console.log("@GLB_SBL: %s", subscriptionTokens[thisSubUser.underlyingToken].globalScaledBalance);
        // console.log("@USR_SBL: %s", adjustedScaledBalance);
        
        subUsers[nftId].scaledBalance = adjustedScaledBalance;
        subUsers[nftId].startTimestamp = time0;
        subUsers[nftId].startLiquidityIndexArraySize = subToken.liquidityIndices.length;
        subscriptionTokens[thisSubUser.underlyingToken].globalScaledBalance -= getScaledBalance(thisSubUser.underlyingToken, interest);
        UserPool(userPool).withdrawUnderlying(subNFT.interestOwnerOf(nftId), thisSubUser.underlyingToken, realInterest);
    }

    function isSubActive(uint256 nftId) public view returns(bool) {
        return(block.timestamp < subUsers[nftId].endTimestamp);
    }

    function deleteStream(uint256 nftId) public onlyOwner {
        subUser memory thisSubUser = subUsers[nftId];
        subscriptionToken memory subToken = subscriptionTokens[thisSubUser.underlyingToken];
        thisSubUser.userStreamWallet.deleteStream(ISuperfluidToken(address(subToken.superToken)), address(providerPool));
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
        subUsers[nftId] = subUser(_underlyingToken, 0, 0, 0, newUserStreamWallet, 0, 0);
        return(nftId);
    }

    function _initPTokens(subscriptionToken memory subToken, uint256 nftId, uint256 realAmount) internal {
        // Mint pTokens
        subToken.pToken.mint(address(this), realAmount);
        // Approve transfer of pTokens by superToken contract
        subToken.pToken.approve(address(subToken.superToken), realAmount);
        // Upgrade pTokens to super pTokens
        // subToken.superToken.upgradeTo(address(subUsers[nftId].userStreamWallet), realAmount, '');
        subToken.superToken.upgrade(realAmount);
        // Transfer super pTokens to userStreamWallet
        subToken.superToken.transfer(address(subUsers[nftId].userStreamWallet), realAmount);
    }

    function getScaledBalance(address underlyingToken, uint256 amount) public view returns(uint256) {
        return(amount.rayDiv(ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(underlyingToken)));
    }

    // Function needs improvements for precision
    function getFlowRate(uint256 _nftId) public view returns(int96){
        return(int96(uint96(subUsers[_nftId].realAmount / period)));
    }
    
    // function testDepositExtra(address underlyingToken, uint256 amount) external {
    //     IERC20(underlyingToken).transferFrom(msg.sender, address(userPool), amount);
    //     UserPool(userPool).depositUnderlying(underlyingToken, amount);
    // }
    
}
