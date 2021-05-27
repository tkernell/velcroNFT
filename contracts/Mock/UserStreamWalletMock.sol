// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ISuperfluidToken {}

interface ISuperfluid {
    function callAgreement(
        ISuperAgreement agreementClass,
        bytes memory callData,
        bytes memory userData
    )
        external
        returns(bytes memory returnedData);
}

interface ISuperAgreement {}

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

contract UserStreamWalletMock is Ownable {
    IConstantFlowAgreementV1 flowAgreement;
    ISuperfluid public superfluidHost;
    
    constructor(address _flowAgreement, address _superfluidHost) {
        flowAgreement = IConstantFlowAgreementV1(_flowAgreement);
        superfluidHost = ISuperfluid(_superfluidHost);
    }
    
    function createStream(address _token, address _receiver, int96 _flowRate) public onlyOwner {
        superfluidHost.callAgreement(
            ISuperAgreement(address(flowAgreement)),
            abi.encodeWithSelector(
                flowAgreement.createFlow.selector,
                ISuperfluidToken(_token),
                _receiver,
                _flowRate,
                new bytes(0)
            ),
            "0x"
        );
    }
}