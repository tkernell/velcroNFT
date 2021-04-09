// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

contract ProviderPool {
    address public owner;
    constructor(address _owner) {
        owner = _owner;
    }
}