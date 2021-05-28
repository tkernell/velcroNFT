// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "./SubscriptionNFT.sol";
import "./PToken.sol";
import "./ProviderPool.sol";
import "./UserPool.sol";

contract Launcher {
    function firstLaunch() external returns(address) {
        SubscriptionNFT subNFT = new SubscriptionNFT(msg.sender);
        return(address(subNFT));
    }
}