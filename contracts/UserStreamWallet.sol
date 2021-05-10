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
    
    function deleteFlow(
        ISuperfluidToken token,
        address sender,
        address receiver,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);
}

contract UserStreamWallet is Ownable {
    IConstantFlowAgreementV1 flowAgreement;
    ISuperfluid public superfluidHost;
    
    constructor(IConstantFlowAgreementV1 _flowAgreement, ISuperfluid _superfluidHost) {
        flowAgreement = _flowAgreement;
        superfluidHost = _superfluidHost;
    }
    
    function createStream(ISuperfluidToken _token, address _receiver, int96 _flowRate) public onlyOwner {
        superfluidHost.callAgreement(
            ISuperAgreement(address(flowAgreement)),
            abi.encodeWithSelector(
                flowAgreement.createFlow.selector,
                _token,
                _receiver,
                _flowRate,
                new bytes(0)
            ),
            "0x"
        );
    }
    
    function deleteStream(ISuperfluidToken _token, address _receiver) public onlyOwner {
        superfluidHost.callAgreement(
            ISuperAgreement(address(flowAgreement)),
            abi.encodeWithSelector(
                flowAgreement.deleteFlow.selector,
                _token,
                address(this),
                _receiver,
                new bytes(0)
            ),
            "0x"
        );
    }
}