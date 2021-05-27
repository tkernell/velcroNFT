// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

interface IInitMock {
    function initialize(uint256 _val) external;
}

contract BeaconFactoryMock is UpgradeableBeacon {
    address[] public plans;

    constructor(address _implementation) UpgradeableBeacon(_implementation) {
        
    }
    
    function createNew(uint256 _val) public {
        address newPlan = address(new BeaconProxy(address(this), ''));
        IInitMock(newPlan).initialize(_val);
        plans.push(newPlan);
    }
}