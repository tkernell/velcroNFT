// SPDX-License-Identifier: MIT

// pragma solidity >= 0.7.0;
pragma solidity 0.7.6;

// import { 
//     ISuperToken,
//     IERC20,
//     ERC20WithTokenInfo
// } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";

// import { ISuperfluid } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol"; 
import { SuperToken } from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";

contract MiniSuperFluidFactory {
    ISuperfluid immutable internal _host;
    
    constructor(ISuperfluid host) {
        _host = host;
    }
    
    function createERC20Wrapper(
        IERC20 underlyingToken,
        string calldata name,
        string calldata symbol
        ) 
        public 
        returns(ISuperToken superToken) 
        {
        
    }
}