// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./Launcher.sol";
import "./VelcroTreasury.sol";

// import "./PlanController.sol";
interface IPlanController {
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
        ) external;
}

contract PlanFactory is UpgradeableBeacon {
    address[] public plans;
    uint256 internal _feePercentage;
    address public launcher;
    VelcroTreasury public treasury;
    
    address public superTokenFactory = 0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561;
    address public constantFlowAgreement = 0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F;
    address public superfluidHost = 0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3;
    address public lendingPool = 0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe;
    address public lendingPoolAddressProvider = 0x88757f2f99175387aB4C6a4b3067c77A695b0349;
    
    constructor(address _implementation) UpgradeableBeacon(_implementation) {
        launcher = address(new Launcher());
        treasury = new VelcroTreasury();
    }
    
    function createPlan(uint256 _periodDays) public {
        address newPlan = address(new BeaconProxy(address(this), ''));
        IPlanController(newPlan).initialize(
            _periodDays, 
            msg.sender, 
            launcher, 
            superTokenFactory, 
            constantFlowAgreement,
            superfluidHost,
            lendingPool,
            lendingPoolAddressProvider,
            address(treasury)
            );
        plans.push(newPlan);
    }
    
    function createProxy() public {
        
    }
    
    function feePercentage() public view returns(uint256) {
        return(_feePercentage);
    }
    
    function updateFeePercentage(uint256 _newFeePercentage) external onlyOwner {
        _feePercentage = _newFeePercentage;
    }
}