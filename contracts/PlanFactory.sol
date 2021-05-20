// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

// import "./PlanController.sol";
interface IPlanController {
    function initialize(uint256 _periodDays) external;
}

contract PlanFactory is UpgradeableBeacon {
    address[] public plans;
    
    constructor(address _implementation) UpgradeableBeacon(_implementation) {}
    
    function createPlan(uint256 _periodDays) public {
        // PlanController newPlan = new PlanController(_periodDays);
        address newPlan = address(new BeaconProxy(address(this), ''));
        // newPlan.transferOwnership(msg.sender);
        plans.push(newPlan);
    }
}