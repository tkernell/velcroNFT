// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "./PlanController.sol";

contract PlanFactory {
    PlanController[] public plans;
    
    function createPlan() public {
        PlanController newPlan = new PlanController(10);
        newPlan.transferOwnership(msg.sender);
        plans.push(newPlan);
    }
}