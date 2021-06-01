// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";

// contract ISuperfluidToken {}
// interface ISuperAgreement {}

// interface ISuperfluid {
//     function callAgreement(
//         ISuperAgreement agreementClass,
//         bytes memory callData,
//         bytes memory userData
//     )
//         external
//         returns(bytes memory returnedData);
// }

// abstract contract IConstantFlowAgreementV1 {
//     function createFlow(
//         ISuperfluidToken token,
//         address receiver,
//         int96 flowRate,
//         bytes calldata ctx
//     )
//         external
//         virtual
//         returns(bytes memory newCtx);
// }

// // // @dev create flow to new receiver
// //         _host.callAgreement(
// //             _cfa,
// //             abi.encodeWithSelector(
// //                 _cfa.createFlow.selector,
// //                 _acceptedToken,
// //                 newReceiver,
// //                 _cfa.getNetFlow(_acceptedToken, address(this)),
// //                 new bytes(0)
// //             ),
// //             "0x"
// //         );

// contract StreamMock2 is Ownable {
//     IConstantFlowAgreementV1 public flowAgreement = IConstantFlowAgreementV1(0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F);
//     ISuperfluid public superfluidHost = ISuperfluid(0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3);
    
    
//     function createStream(ISuperfluidToken _token, address _receiver, int96 _flowRate, bytes calldata _ctx) public onlyOwner {
//         flowAgreement.createFlow(_token, _receiver, _flowRate, _ctx);
//     }
    
//     function createStream2(ISuperfluidToken _token, address _receiver, int96 _flowRate) public onlyOwner {
//         superfluidHost.callAgreement(
//             ISuperAgreement(address(flowAgreement)),
//             abi.encodeWithSelector(
//                 flowAgreement.createFlow.selector,
//                 _token,
//                 _receiver,
//                 _flowRate,
//                 new bytes(0)
//             ),
//             "0x"
//         );
//     }
// }