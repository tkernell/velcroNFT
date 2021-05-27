// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

abstract contract ISuperToken {
    /**
     * @dev Returns the amount of tokens owned by an account (`owner`).
     */
    function balanceOf(address account) virtual external view returns(uint256 balance);
    function transfer(address recipient, uint256 amount) virtual external returns (bool);
    /**
     * @dev Upgrade ERC20 to SuperToken.
     * @param amount Number of tokens to be upgraded (in 18 decimals)
     *
     * NOTE: It will use ´transferFrom´ to get tokens. Before calling this
     * function you should ´approve´ this contract
     */
    function upgrade(uint256 amount) virtual external;
    function downgrade(uint256 amount) virtual external;

    /**
     * @dev Upgrade ERC20 to SuperToken and transfer immediately
     * @param to The account to received upgraded tokens
     * @param amount Number of tokens to be upgraded (in 18 decimals)
     * @param data User data for the TokensRecipient callback
     *
     * NOTE: It will use ´transferFrom´ to get tokens. Before calling this
     * function you should ´approve´ this contract
     */
    function upgradeTo(address to, uint256 amount, bytes calldata data) virtual external;
}

contract ReceiverMock {
    ISuperToken public superToken;
    
    constructor(address _superToken) {
        superToken = ISuperToken(_superToken);
    }
    
    function downgrade(uint256 _amount) public {
        superToken.downgrade(_amount);
    }
}