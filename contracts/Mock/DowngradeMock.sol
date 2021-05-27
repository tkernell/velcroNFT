// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "../PToken.sol";
import { ReceiverMock } from "./ReceiverMock.sol";
import { UserStreamWalletMock } from "./UserStreamWalletMock.sol";

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

contract ISuperTokenFactory {
    /**
     * @dev Upgradability modes
     */
    enum Upgradability {
        /// Non upgradable super token, `host.updateSuperTokenLogic` will revert
        NON_UPGRADABLE,
        /// Upgradable through `host.updateSuperTokenLogic` operation
        SEMI_UPGRADABLE,
        /// Always using the latest super token logic
        FULL_UPGRADABE
    }

    function createERC20Wrapper(
        IERC20 underlyingToken,
        uint8 underlyingDecimals,
        Upgradability upgradability,
        string calldata name,
        string calldata symbol
    ) public returns (ISuperToken superToken) {}
}

interface ISuperfluidToken {}

interface ISuperAgreement {}

interface ISuperfluid {
    function callAgreement(
        ISuperAgreement agreementClass,
        bytes memory callData,
        bytes memory userData
    )
        external
        returns(bytes memory returnedData);
}

abstract contract IConstantFlowAgreementV1 {
    function createFlow(
        ISuperfluidToken token,
        address receiver,
        int96 flowRate,
        bytes calldata ctx
    )
        external
        virtual
        returns(bytes memory newCtx);
}

contract DowngradeMock {
    PToken public pToken;
    ISuperToken public superToken;
    address public receiver;
    UserStreamWalletMock public userStreamWallet;
    
    IConstantFlowAgreementV1 flowAgreement = IConstantFlowAgreementV1(0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F);
    // Superfluid host on Kovan: 0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3
    ISuperfluid superfluidHost = ISuperfluid(0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3);
    // SuperTokenFactory on Kovan: 0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561
    ISuperTokenFactory superTokenFactory = ISuperTokenFactory(0xF5F666AC8F581bAef8dC36C7C8828303Bd4F8561);
    
    constructor() {
        pToken = new PToken();
        superToken = superTokenFactory.createERC20Wrapper(
            IERC20(address(pToken)),
            18,
            ISuperTokenFactory.Upgradability.NON_UPGRADABLE,
            "Super pToken",
            "pTKNx"
        );
        
        receiver = address(new ReceiverMock(address(superToken)));
        userStreamWallet = new UserStreamWalletMock(address(flowAgreement), address(superfluidHost));
        
    }
    
    function mint(address _to, uint256 _amount) public {
        pToken.mint(_to, _amount);
    }
    
    function upgrade(uint256 _amount) public {
        pToken.approve(address(superToken), _amount);
        superToken.upgrade(_amount);
    }
    
    function startStream(address _receiver, int96 _flowRate) public {
        superfluidHost.callAgreement(
            ISuperAgreement(address(flowAgreement)),
            abi.encodeWithSelector(
                flowAgreement.createFlow.selector,
                pToken,
                _receiver,
                _flowRate,
                new bytes(0)
            ),
            "0x"
        );
    }
    
    function streamFromWallet(uint256 _amount, address _receiver, int96 _flowRate) public {
        superToken.transfer(address(userStreamWallet), _amount);
        userStreamWallet.createStream(address(superToken), _receiver, _flowRate);
    }
}