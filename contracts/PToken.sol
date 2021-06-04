// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PToken is ERC20, Ownable {
    
    /**
     * @dev Constructor which sets token parameters
     */
    constructor() ERC20("PToken", "PTKN") {}
    
    /**
     * @dev Mint new tokens
     * @param _to Recipient of tokens
     * @param _amount How much to mint
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
    
    /**
     * @dev Burn tokens
     * @param _account Owner of tokens to burn
     * @param _amount How much to burn
     */
    function burn(address _account, uint256 _amount) public onlyOwner {
        _burn(_account, _amount);
    }
}