// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Launcher } from "./Launcher.sol";
import "./VelcroTreasury.sol";

interface IPlanController {
    function initialize(
        uint256 _period, 
        address _owner, 
        address _launcher, 
        address _superTokenFactory, 
        address _constantFlowAgreement, 
        address _superfluidHost,
        address _lendingPoolAddressProvider
        ) external;
}

contract PlanFactory is UpgradeableBeacon {
    
    event PlanCreated(address _plan, address _creator);
    
    address[] public plans;
    uint256 internal _feePercentage;
    uint256 internal _keeperFeePercentage;
    address public launcher;
    address public treasury;
    
    address public superTokenFactory = 0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561;
    address public constantFlowAgreement = 0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F;
    address public superfluidHost = 0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3;
    address public lendingPoolAddressProvider = 0x88757f2f99175387aB4C6a4b3067c77A695b0349;
    
    constructor(address _implementation) UpgradeableBeacon(_implementation) {
        launcher = address(new Launcher());
        treasury = address(new VelcroTreasury());
    }

     /**
     * @dev Create a new subscription plan factory
     * @param _period Subscription base length
     */
    function createPlan(uint256 _period) public {
        address newPlan = address(new BeaconProxy(address(this), ''));
        IPlanController(newPlan).initialize(
            _period, 
            msg.sender, 
            launcher, 
            superTokenFactory, 
            constantFlowAgreement,
            superfluidHost,
            lendingPoolAddressProvider
            );
        plans.push(newPlan);
        
        emit PlanCreated(newPlan, msg.sender);
    }
    
    /**
     * @dev Returns fee as percentage of subscription payment
     * @return uint256 Fee percentage
     */
    function feePercentage() public view returns(uint256) {
        return(_feePercentage);
    }
    
    /**
     * @dev Returns keeper fee as percentage of accumulated interest
     * @return uint256 Keeper fee percentage
     */
    function keeperFeePercentage() public view returns(uint256) {
        return(_keeperFeePercentage);
    }
    
    /**
     * @dev Change fee percentage
     * @param _newFeePercentage The new fee percentage
     */
    function updateFeePercentage(uint256 _newFeePercentage) external onlyOwner {
        _feePercentage = _newFeePercentage;
    }
    
    /**
     * @dev Change fee percentage
     * @param _newKeeperFeePercentage The new fee percentage
     */
    function updateKeeperFeePercentage(uint256 _newKeeperFeePercentage) external onlyOwner {
        _keeperFeePercentage = _newKeeperFeePercentage;
    }
    
    function transferTokensFromTreasury(address _token, address _to, uint256 _amount) external onlyOwner {
        VelcroTreasury(treasury).transferToken(_token, _to, _amount);
    }
    
    function updateTreasuryAddress(address _newTreasuryAddress) external onlyOwner {
        treasury = _newTreasuryAddress;
    }
    
    function updateLauncherAddress(address _newLauncherAddress) external onlyOwner {
        launcher = _newLauncherAddress;
    }
    
    function updateLendingPoolAddressProvider(address _newLendingPoolAddressProvider) external onlyOwner {
        lendingPoolAddressProvider = _newLendingPoolAddressProvider;
    }
    
    function updateSuperTokenFactory(address _newSuperTokenFactory) external onlyOwner {
        superTokenFactory = _newSuperTokenFactory;
    }
    
    function updateConstantFlowAgreement(address _newConstantFlowAgreement) external onlyOwner {
        constantFlowAgreement = _newConstantFlowAgreement;
    }
    
    
    
}