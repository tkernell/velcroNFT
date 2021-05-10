// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "./PlanController.sol";

contract PlanFactory {
    PlanController[] public plans;
    
    function createPlan(uint256 _periodDays) public {
        PlanController newPlan = new PlanController(_periodDays);
        newPlan.transferOwnership(msg.sender);
        plans.push(newPlan);
    }
}