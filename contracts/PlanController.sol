// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SubscriptionNFT.sol";
import "./UserPool.sol";
import { ProviderPool } from "./ProviderPool.sol";
import "./PToken.sol";
import "./UserStreamWallet.sol";
import "./Aave/WadRayMath.sol";
import "./Aave/ILendingPoolAddressesProviderV2.sol";

import "hardhat/console.sol";

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
    /**
     * @dev Returns the amount of tokens owned by an account (`owner`).
     */
    function balanceOf(address account) virtual external view returns(uint256 balance);
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

interface ILendingPool {
    /**
   * @dev Returns the normalized income normalized income of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome(address asset) external view returns (uint256);
}

contract PlanController is Ownable {
    using WadRayMath for uint256;
    SubscriptionNFT public subNFT;
    address public userPool;
    address public providerPool;
    uint256 public period;
    // SuperTokenFactory on Matic: 0x2C90719f25B10Fc5646c82DA3240C76Fa5BcCF34
    // SuperTokenFactory on Kovan: 0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561
    ISuperTokenFactory superTokenFactory = ISuperTokenFactory(0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561);
    // ConstantFlowAgreementV1 on Matic: 0x6EeE6060f715257b970700bc2656De21dEdF074C
    // ConstantFlowAgreementV1 on Kovan: 0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F
    IConstantFlowAgreementV1 constantFlowAgreement = IConstantFlowAgreementV1(0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F);
    // Aave LendingPool on Matic: 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf
    // Aave LendingPool on Kovan: 0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe
    ILendingPool lendingPool = ILendingPool(0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe);
    // Aave LendingPoolAddressesProviderV2 on Matic: 0xd05e3E715d945B59290df0ae8eF85c1BdB684744
    // Aave LendingPoolAddressesProviderV2 on Kovan: 0x88757f2f99175387aB4C6a4b3067c77A695b0349
    ILendingPoolAddressesProviderV2 lendingPoolAddressesProvider = ILendingPoolAddressesProviderV2(0x88757f2f99175387aB4C6a4b3067c77A695b0349);
    // Superfluid host on Matic:
    // Superfluid host on Kovan: 0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3
    ISuperfluid superfluidHost = ISuperfluid(0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3);

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
    }

    mapping(address => subscriptionToken) public subscriptionTokens;
    // Mapping from NFT Token ID to subUser
    mapping(uint256 => subUser) public subUsers;

    modifier onlyNftOwner(uint256 _nftId) {
        require(msg.sender == subNFT.ownerOf(_nftId));
        _;
    }

    constructor(uint256 _periodDays) {
        period = _periodDays * 1 days;
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

        // Mint, approve, upgrade, transfer pToken
        _initPTokens(subToken, nftId);

        // start Superfluid Stream
        newSubUser.userStreamWallet.createStream(
            ISuperfluidToken(address(subToken.superToken)),
            providerPool,
            getFlowRate(underlyingToken)
        );

        // Transfer underlying token from user to userPool
        IERC20(underlyingToken).transferFrom(msg.sender, address(userPool), subToken.price);
        // Convert underlying token to aToken through userPool
        UserPool(userPool).depositUnderlying(underlyingToken, subToken.price);
        // Record scaled balance
        subUsers[nftId].scaledBalance = getScaledBalance(underlyingToken, subToken.price);
        // Record subscription start timestamp
        subUsers[nftId].startTimestamp = block.timestamp;
        // Record subscription end timestamp
        subUsers[nftId].endTimestamp = block.timestamp + period;
        // Record liquidityIndices array size
        subUsers[nftId].startLiquidityIndexArraySize = subToken.liquidityIndices.length;
        // Add user's scaled balance to global scaled balance
        subscriptionTokens[underlyingToken].globalScaledBalance += subUsers[nftId].scaledBalance;
    }

    function providerWithdrawal(address _underlyingToken) public onlyOwner {
        // Amount = super pToken balance of providerPool
        uint256 amount = subscriptionTokens[_underlyingToken].superToken.balanceOf(providerPool);
        console.log("@PRW_AMT: %s", amount);
        // Convert 'amount' of aTokens from userPool back to underlyingToken
        // Send 'amount' to provider (owner)
        UserPool(userPool).withdrawUnderlying(owner(), _underlyingToken, amount);
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

        uint256 adjustedScaledBalance = thisSubUser.scaledBalance;
        uint256 i = thisSubUser.startLiquidityIndexArraySize;
        uint256 time0 = thisSubUser.startTimestamp;
        while (i < subToken.liquidityIndices.length && subToken.providerWithdrawalTimestamps[i] <= thisSubUser.endTimestamp) {
            uint256 time1 = subToken.providerWithdrawalTimestamps[i];
            adjustedScaledBalance = adjustedScaledBalance - (time1 - time0) * (uint256(int256(getFlowRate(thisSubUser.underlyingToken)))).rayDiv(subToken.liquidityIndices[i]);
            time0 = time1;
            i += 1;
        }

        uint256 interest;
        uint256 currentLiquidityIndex = ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(thisSubUser.underlyingToken);
        // If the subscription period has not ended...
        if (block.timestamp < thisSubUser.endTimestamp) {
            // interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - subToken.superToken.balanceOf(address(thisSubUser.userStreamWallet));
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - ((thisSubUser.endTimestamp - time0 + 1) * (uint256(int256(getFlowRate(thisSubUser.underlyingToken)))));
            adjustedScaledBalance = adjustedScaledBalance - interest.rayDiv(currentLiquidityIndex);
        // Else if the subscription period has ended and no principal remains...
        } else if (subToken.providerWithdrawalTimestamps.length > 0 && subToken.providerWithdrawalTimestamps[subToken.providerWithdrawalTimestamps.length - 1] > thisSubUser.endTimestamp) {
            interest = currentLiquidityIndex.rayMul(adjustedScaledBalance - (thisSubUser.endTimestamp - time0)*(uint256(int256(getFlowRate(thisSubUser.underlyingToken)))).rayDiv(subToken.liquidityIndices[i]));
            adjustedScaledBalance = 0;
        // Need another elseif for when user withdraws after endTimestamp, still some principal left, and user withdraws again
        } else {
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - (thisSubUser.endTimestamp - time0)*(uint256(int256(getFlowRate(thisSubUser.underlyingToken))));
            adjustedScaledBalance = adjustedScaledBalance - interest.rayDiv(currentLiquidityIndex);
        }
        
        // Get real interest to withdraw
        uint256 pTokenSupply = IERC20(address(subToken.superToken)).totalSupply();
        uint256 aTokenBalance = IERC20(UserPool(userPool).getReserveInterestToken(thisSubUser.underlyingToken)).balanceOf(userPool);
        // uint256 globalInterest = subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - pTokenSupply;
        uint256 realInterest = interest * (aTokenBalance - pTokenSupply) / (subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - pTokenSupply);
        console.log("@RealInt: %s", realInterest);
        console.log("@GLB_INT: %s", subToken.globalScaledBalance.rayMul(currentLiquidityIndex) - pTokenSupply);
        console.log("@USR_INT: %s", interest);
        console.log("@GLB_SBL: %s", subscriptionTokens[thisSubUser.underlyingToken].globalScaledBalance);
        console.log("@USR_SBL: %s", adjustedScaledBalance);
        
        subUsers[nftId].scaledBalance = adjustedScaledBalance;
        subUsers[nftId].startTimestamp = time0;
        subUsers[nftId].startLiquidityIndexArraySize = subToken.liquidityIndices.length;
        subscriptionTokens[thisSubUser.underlyingToken].globalScaledBalance -= getScaledBalance(thisSubUser.underlyingToken, interest);
        UserPool(userPool).withdrawUnderlying(subNFT.ownerOf(nftId), thisSubUser.underlyingToken, realInterest);
    }
    
    function withdrawInterest2(uint256 nftId) public onlyNftOwner(nftId) {
        subUser memory thisSubUser = subUsers[nftId];
        subscriptionToken memory subToken = subscriptionTokens[thisSubUser.underlyingToken];
        require(thisSubUser.scaledBalance > 0);

        uint256 adjustedScaledBalance = thisSubUser.scaledBalance;
        uint256 i = thisSubUser.startLiquidityIndexArraySize;
        uint256 time0 = thisSubUser.startTimestamp;
        // Subtract each provider withdrawal amount before user's subscription end timestamp
        while (i < subToken.liquidityIndices.length && subToken.providerWithdrawalTimestamps[i] < thisSubUser.endTimestamp) {
            adjustedScaledBalance -= ((subToken.providerWithdrawalTimestamps[i] - time0) * uint256(int256(getFlowRate(thisSubUser.underlyingToken)))).rayDiv(subToken.liquidityIndices[i]);
            time0 = subToken.providerWithdrawalTimestamps[i];
            i++;
        }
        
        uint256 currentLiquidityIndex = ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(thisSubUser.underlyingToken);
        uint256 interest;
        if (block.timestamp < thisSubUser.endTimestamp) {
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - ((thisSubUser.endTimestamp - time0) * uint256(int256(getFlowRate(thisSubUser.underlyingToken))));
            adjustedScaledBalance = adjustedScaledBalance - getScaledBalance(thisSubUser.underlyingToken, interest);
        } else if (subToken.liquidityIndices.length >= i) {
            interest = adjustedScaledBalance.rayMul(subToken.liquidityIndices[i]) - ((thisSubUser.endTimestamp - time0) * uint256(int256(getFlowRate(thisSubUser.underlyingToken))));
            adjustedScaledBalance = 0;
        } else {
            interest = adjustedScaledBalance.rayMul(currentLiquidityIndex) - ((thisSubUser.endTimestamp - time0) * uint256(int256(getFlowRate(thisSubUser.underlyingToken))));
        }
        
        subUsers[nftId].startLiquidityIndexArraySize = i;
        
    }

    function isSubActive(uint256 nftId) public view onlyOwner returns(bool) {
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
        subUsers[nftId] = subUser(_underlyingToken, 0, 0, 0, newUserStreamWallet, 0);
        return(nftId);
    }

    function _initPTokens(subscriptionToken memory subToken, uint256 nftId) internal {
        // Mint pTokens
        subToken.pToken.mint(address(this), subToken.price);
        // Approve transfer of pTokens by superToken contract
        subToken.pToken.approve(address(subToken.superToken), subToken.price);
        // Upgrade pTokens to super pTokens
        subToken.superToken.upgrade(subToken.price);
        // Transfer super pTokens to userStreamWallet
        subToken.superToken.transfer(address(subUsers[nftId].userStreamWallet), subToken.price);
    }

    function getScaledBalance(address underlyingToken, uint256 amount) public view returns(uint256) {
        return(amount.rayDiv(ILendingPool(lendingPoolAddressesProvider.getLendingPool()).getReserveNormalizedIncome(underlyingToken)));
    }

    // Function needs improvements for precision
    function getFlowRate(address underlyingToken) public view returns(int96){
        return(int96(uint96(subscriptionTokens[underlyingToken].price / period)));
    }
    
    function testDepositExtra(address underlyingToken, uint256 amount) external {
        IERC20(underlyingToken).transferFrom(msg.sender, address(userPool), amount);
        UserPool(userPool).depositUnderlying(underlyingToken, amount);
    }
    
    
}
