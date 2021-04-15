// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ISuperfluidToken {}

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

contract UserStreamWallet is Ownable {
    IConstantFlowAgreementV1 flowAgreement;
    
    constructor(IConstantFlowAgreementV1 _flowAgreement) {
        flowAgreement = _flowAgreement;
    }
    
    function createStream(ISuperfluidToken _token, address _receiver, int96 _flowRate, bytes calldata _ctx) public onlyOwner {
        flowAgreement.createFlow(_token, _receiver, _flowRate, _ctx);
    }
}