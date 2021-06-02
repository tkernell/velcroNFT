// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.0;

// interface IERC20 {}

// contract ISuperTokenFactory {
//     /**
//      * @dev Upgradability modes
//      */
//     enum Upgradability {
//         /// Non upgradable super token, `host.updateSuperTokenLogic` will revert
//         NON_UPGRADABLE,
//         /// Upgradable through `host.updateSuperTokenLogic` operation
//         SEMI_UPGRADABLE,
//         /// Always using the latest super token logic
//         FULL_UPGRADABE
//     }

//     function createERC20Wrapper(
//         IERC20 underlyingToken,
//         uint8 underlyingDecimals,
//         Upgradability upgradability,
//         string calldata name,
//         string calldata symbol
//     ) public returns (ISuperToken superToken) {}
// }

// abstract contract ISuperToken {
//     /**
//      * @dev Returns the amount of tokens owned by an account (`owner`).
//      */
//     function balanceOf(address account) virtual external view returns(uint256 balance);
//     function transfer(address recipient, uint256 amount) virtual external returns (bool);
//     /**
//      * @dev Upgrade ERC20 to SuperToken.
//      * @param amount Number of tokens to be upgraded (in 18 decimals)
//      *
//      * NOTE: It will use ´transferFrom´ to get tokens. Before calling this
//      * function you should ´approve´ this contract
//      */
//     function upgrade(uint256 amount) virtual external;

//     /**
//      * @dev Upgrade ERC20 to SuperToken and transfer immediately
//      * @param to The account to received upgraded tokens
//      * @param amount Number of tokens to be upgraded (in 18 decimals)
//      * @param data User data for the TokensRecipient callback
//      *
//      * NOTE: It will use ´transferFrom´ to get tokens. Before calling this
//      * function you should ´approve´ this contract
//      */
//     function upgradeTo(address to, uint256 amount, bytes calldata data) virtual external;
// }

// contract ApproveTokenMock {
//     ISuperTokenFactory public superTokenFactory = ISuperTokenFactory(0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561);
    
//     function approveToken6(address _underlyingToken, ISuperTokenFactory.Upgradability _upgradability) public {
//         superTokenFactory.createERC20Wrapper(
//             IERC20(_underlyingToken),
//             18,
//             ISuperTokenFactory.Upgradability(_upgradability),
//             "Super pToken",
//             "pTKNx"
//         );
//     }
// }

