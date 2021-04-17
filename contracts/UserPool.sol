// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IAaveBridge {
    function deposit(address assetToken, uint256 assetAmount) external returns (uint256);
    function withdraw(address receiver, address assetToken, uint256 assetAmount) external;
}

contract UserPool is Ownable {
    
    IAaveBridge public bridge = IAaveBridge(address(0));
    
    function depositUnderlying(address assetToken, uint256 assetAmount) public onlyOwner {
        bridge.deposit(assetToken, assetAmount);
    }
    
    function withdrawUnderlying(address receiver, address assetToken, uint256 assetAmount) public onlyOwner {
        bridge.withdraw(receiver, assetToken, assetAmount);
    }
}