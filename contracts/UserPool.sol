// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAaveBridge {
    function deposit(address assetToken, uint256 assetAmount, uint256 referralCode) external returns (uint256);
    function withdraw(address receiver, address assetToken, uint256 assetAmount) external;
    function getReserveInterestToken(address assetToken) external view returns (address aTokenAddress);
}

contract UserPool is Ownable {
    // AaveBridgeV2 on Kovan: 0x4922EEBff2D2d82dd112B1D662Fd72B948a3C16E
    IAaveBridge public bridge = IAaveBridge(0x4922EEBff2D2d82dd112B1D662Fd72B948a3C16E);
    
    function depositUnderlying(address assetToken, uint256 assetAmount) external onlyOwner {
        IERC20(assetToken).transfer(address(bridge), assetAmount);
        bridge.deposit(assetToken, assetAmount, 0);
    }
    
    function withdrawUnderlying(address receiver, address assetToken, uint256 assetAmount) external onlyOwner {
        IERC20(bridge.getReserveInterestToken(assetToken)).transfer(address(bridge), assetAmount);
        bridge.withdraw(receiver, assetToken, assetAmount);
    }
}