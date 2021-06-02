// const { expect } = require("chai");
// const { time } = require("@openzeppelin/test-helpers");
//
// const precision = BigInt(1e18);
// const MINT_AMOUNT = BigInt(1) * precision;
// const FLOW_RATE = BigInt(1) * BigInt(1e14);
//
// describe("DowngradeMock", function() {
//
//   let downgradeMock;
//   let receiverMock;
//   let pToken;
//   let superToken;
//
//   beforeEach(async function () {
//     [owner, addr1, addr2] = await ethers.getSigners();
//
//     const DowngradeMock = await ethers.getContractFactory("DowngradeMock");
//     downgradeMock = await DowngradeMock.deploy();
//     await downgradeMock.deployed();
//
//     let receiverAddress = await downgradeMock.receiver();
//     const ReceiverMock = await ethers.getContractFactory("ReceiverMock");
//     receiverMock = await ReceiverMock.attach(receiverAddress);
//
//     let pTokenAddress = await downgradeMock.pToken();
//     const ERC20 = await ethers.getContractFactory("ERC20");
//     pToken = await ERC20.attach(pTokenAddress);
//
//     let superTokenAddress = await downgradeMock.superToken();
//     superToken = await ERC20.attach(superTokenAddress);
//   });
//
//   it("Mint", async function() {
//     await downgradeMock.mint(downgradeMock.address, MINT_AMOUNT);
//     await downgradeMock.upgrade(MINT_AMOUNT);
//     console.log("DWNGR_tknX: " + await superToken.balanceOf(downgradeMock.address));
//     // await downgradeMock.startStream(receiverMock.address, 10000000000);
//     await downgradeMock.streamFromWallet(MINT_AMOUNT, receiverMock.address, FLOW_RATE);
//
//     let timeDelay0 = 100000;
//     await time.increase(timeDelay0);
//     console.log("Time delay: " + timeDelay0);
//
//     console.log("RECVR_tknX: " + await superToken.balanceOf(receiverMock.address));
//
//     let timeDelay1 = 100000;
//     await time.increase(timeDelay1);
//     console.log("Time delay: " + timeDelay1);
//
//     console.log("RECVR_tknX: " + await superToken.balanceOf(receiverMock.address));
//
//     let timeDelay2 = 1;
//     await time.increase(timeDelay2);
//     console.log("Time delay: " + timeDelay2);
//
//     console.log("RECVR_tknX: " + await superToken.balanceOf(receiverMock.address));
//     let receiverBal = await superToken.balanceOf(receiverMock.address);
//
//     await receiverMock.downgrade(receiverBal);
//
//   })
// })
