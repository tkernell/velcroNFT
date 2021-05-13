const { expect } = require("chai");
const { time } = require("@openzeppelin/test-helpers");

const precision = BigInt(1e18);
const DAI_KOVAN_ADDRESS = "0xff795577d9ac8bd7d90ee22b6c1703490b6512fd";
const AAVE_BRIDGE_ADDRESS = "0x4922EEBff2D2d82dd112B1D662Fd72B948a3C16E";
const SUBSCRIPTION_PRICE = BigInt(2) * precision;
const NDAYS = 2;



describe("PlanController", function() {

  let planController;
  let daiContract;
  let aDaiContract;
  let aaveBridgeContract;
  let nftContract;
  let pDaiXContract;
  let pDaiContract;
  let owner, addr1, addr2, addr3;

  async function providerWithdrawal(token) {
    console.log("**** Provider Withdrawal **** ");
    await planController.providerWithdrawal(token);
  };

  async function withdrawInterest(user, nftId) {
    console.log("**** Interest Withdrawal " + nftId + " ****");
    await planController.connect(user).withdrawInterest(nftId);
  };

  async function deleteStream(user, nftId) {
    console.log("**** Stream Deleted " + nftId + " ****");
    await planController.connect(user).deleteStream(nftId);
  };

  beforeEach(async function () {
    const ERC20Contract = await ethers.getContractFactory("ERC20");
    daiContract = await ERC20Contract.attach(DAI_KOVAN_ADDRESS);

    const PlanController = await ethers.getContractFactory("PlanController");
    planController = await PlanController.deploy(NDAYS);
    [owner, addr1, addr2] = await ethers.getSigners();
    await planController.deployed();

    let nftAddress = await planController.subNFT();
    const NftContract = await ethers.getContractFactory("SubscriptionNFT");
    nftContract = await NftContract.attach(nftAddress);

    await planController.approveToken(DAI_KOVAN_ADDRESS, SUBSCRIPTION_PRICE);

    let daiSubStruct = await planController.subscriptionTokens(DAI_KOVAN_ADDRESS);
    pDaiContract = await ERC20Contract.attach(daiSubStruct.pToken);
    pDaiXContract = await ERC20Contract.attach(daiSubStruct.superToken);

    const AaveBridge = await ethers.getContractFactory("AaveBridgeV2");
    aaveBridgeContract = await AaveBridge.attach(AAVE_BRIDGE_ADDRESS);

    let aDaiAddress = await aaveBridgeContract.getReserveInterestToken(DAI_KOVAN_ADDRESS);
    aDaiContract = await ERC20Contract.attach(aDaiAddress);

    await daiContract.transfer(addr2.address, await daiContract.balanceOf(owner.address));



  });

  // it("Should set deployer as owner", async function() {
  //   expect(await planController.owner()).to.equal(owner.address);
  // });
  //
  // it("Should be able to approve token", async function() {
  //   expect(await planController.tokenIsActive(DAI_KOVAN_ADDRESS)).to.equal(true);
  // });
  //
  // it("Should be able to mint NFT", async function() {
  //   await planController.connect(addr1).createSubscription(DAI_KOVAN_ADDRESS);
  //   await daiContract.connect(addr1).approve(planController.address, SUBSCRIPTION_PRICE);
  //   await planController.connect(addr1).fundSubscription(0);
  //   expect(await nftContract.ownerOf(0)).to.equal(addr1.address);
  // });
  //
  // it("Test provider withdrawal", async function() {
  //   await planController.connect(addr1).createSubscription(DAI_KOVAN_ADDRESS);
  //   await daiContract.connect(addr1).approve(planController.address, SUBSCRIPTION_PRICE);
  //   await planController.connect(addr1).fundSubscription(0);
  //
  //   let subscriberStruct = await planController.subUsers(0);
  //   let providerPoolAddress = await planController.providerPool();
  //   console.log("Flow rate: " + await planController.getFlowRate(DAI_KOVAN_ADDRESS));
  //   console.log("PPL_DAIX: " + await pDaiXContract.balanceOf(providerPoolAddress));
  //   console.log("USW_DAIX: " + await pDaiXContract.balanceOf(subscriberStruct.userStreamWallet));
  //   console.log("UPL_ADAI: " + await aDaiContract.balanceOf(await planController.userPool()));
  //   console.log("PDAIX_TS: " + await pDaiXContract.totalSupply());
  //   let timeDelay0 = 10000000;
  //   await time.increase(timeDelay0);
  //   console.log("Time increase " + timeDelay0 + " seconds");
  //   console.log("PPL_DAIX: " + await pDaiXContract.balanceOf(providerPoolAddress));
  //   console.log("USW_DAIX: " + await pDaiXContract.balanceOf(subscriberStruct.userStreamWallet));
  //   console.log("OWNR_DAI: " + await daiContract.balanceOf(owner.address));
  //   // await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
  //   // console.log("Provider Withdrawal...");
  //   console.log("PPL_DAIX: " + await pDaiXContract.balanceOf(providerPoolAddress));
  //   console.log("USW_DAIX: " + await pDaiXContract.balanceOf(subscriberStruct.userStreamWallet));
  //   console.log("OWNR_DAI: " + await daiContract.balanceOf(owner.address));
  //   console.log("UPL_ADAI: " + await aDaiContract.balanceOf(await planController.userPool()));
  //   console.log("PDAIX_TS: " + await pDaiXContract.totalSupply());
  //   let timeDelay1 = 1;
  //   await time.increase(timeDelay1);
  //   console.log("Time increase " + timeDelay1 + " seconds");
  //   console.log("PPL_DAIX: " + await pDaiXContract.balanceOf(providerPoolAddress));
  //   console.log("USW_DAIX: " + await pDaiXContract.balanceOf(subscriberStruct.userStreamWallet));
  //   console.log("PLC_DAIX: " + await pDaiXContract.balanceOf(planController.address));
  //   console.log("OWNR_DAI: " + await daiContract.balanceOf(owner.address));
  //   console.log("UPL_ADAI: " + await aDaiContract.balanceOf(await planController.userPool()));
  //   console.log("PDAIX_TS: " + await pDaiXContract.totalSupply());
  // });
  //
  // it("Test withdraw interest", async function() {
  //   await planController.connect(addr1).createSubscription(DAI_KOVAN_ADDRESS);
  //   await daiContract.connect(addr1).approve(planController.address, SUBSCRIPTION_PRICE);
  //   await planController.connect(addr1).fundSubscription(0);
  //   console.log("Addr1 DAI: " + await daiContract.balanceOf(addr1.address));
  //   await time.increase(1);
  //   await planController.connect(addr1).withdrawInterest(0);
  //   console.log("Addr1 DAI: " + await daiContract.balanceOf(addr1.address));
  //   await time.increase(1);
  //   await planController.connect(addr1).withdrawInterest(0);
  //   console.log("Addr1 DAI: " + await daiContract.balanceOf(addr1.address));
  //   await time.increase(1);
  //   await planController.connect(addr1).withdrawInterest(0);
  //   console.log("Addr1 DAI: " + await daiContract.balanceOf(addr1.address));
  //   await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
  // });

  // it("Test full process", async function() {
  //
  //   await planController.connect(addr1).createSubscription(DAI_KOVAN_ADDRESS);
  //   await planController.connect(addr2).createSubscription(DAI_KOVAN_ADDRESS);
  //   await daiContract.connect(addr1).approve(planController.address, await daiContract.balanceOf(addr1.address));
  //   await daiContract.connect(addr2).approve(planController.address, await daiContract.balanceOf(addr2.address));
  //   await planController.connect(addr1).fundSubscription(0);
  //   await planController.connect(addr2).fundSubscription(1);
  //   // await daiContract.connect(addr1).transfer(addr2.address, await daiContract.balanceOf(addr1.address));
  //   // await daiContract.connect(addr1).transfer(await planController.userPool(), await daiContract.balanceOf(addr1.address));
  //   await planController.connect(addr1).testDepositExtra(DAI_KOVAN_ADDRESS, await daiContract.balanceOf(addr1.address));
  //   await planController.connect(addr2).testDepositExtra(DAI_KOVAN_ADDRESS, await daiContract.balanceOf(addr2.address));
  //   let providerPoolAddress = await planController.providerPool();
  //   let subscriberStruct = await planController.subUsers(0);
  //
  //   async function spitout() {
  //     console.log("PPL_DAIX: " + await pDaiXContract.balanceOf(providerPoolAddress));
  //     console.log("USW_DAIX: " + await pDaiXContract.balanceOf(subscriberStruct.userStreamWallet));
  //     console.log("OWNR_DAI: " + await daiContract.balanceOf(owner.address));
  //     console.log("ADR1_DAI: " + await daiContract.balanceOf(addr1.address));
  //     console.log("ADR2_DAI: " + await daiContract.balanceOf(addr2.address));
  //     console.log("UPL_ADAI: " + await aDaiContract.balanceOf(await planController.userPool()));
  //     console.log("PDAIX_TS: " + await pDaiXContract.totalSupply());
  //   };
  //
  //   await spitout();
  //   await delay(50000);
  //
  //   await spitout();
  //
  //   await providerWithdrawal(DAI_KOVAN_ADDRESS);
  //
  //   await spitout();
  //
  //   // await withdrawInterest(addr1, 0);
  //   await planController.connect(addr1).withdrawInterest(0);
  //   console.log("**** Interest Withdrawal ****");
  //
  //   await spitout();
  //
  //   await delay(50000);
  //   // await delay(169198);
  //   await spitout();
  //
  //   await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
  //   console.log("**** Provider Withdrawal **** ");
  //
  //   await spitout();
  //
  //   await planController.connect(addr1).withdrawInterest(0);
  //   console.log("**** Interest Withdrawal ****");
  //
  //   await spitout();
  //
  //   await delay(50000);
  //   // await delay(169198);
  //   await spitout();
  //
  //   await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
  //   console.log("**** Provider Withdrawal **** ");
  //
  //   await spitout();
  //
  //   await planController.connect(addr1).withdrawInterest(0);
  //   console.log("**** Interest Withdrawal ****");
  //
  //   await spitout();
  //
  //   await delay(22000);
  //   // await delay(169198);
  //   await spitout();
  //
  //   await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
  //   console.log("**** Provider Withdrawal **** ");
  //
  //   await spitout();
  //
  //   await planController.connect(addr1).withdrawInterest(0);
  //   console.log("**** Interest Withdrawal ****");
  //
  //   await spitout();
  //
  //   await planController.deleteStream(0);
  //   console.log("**** STREAM DELETED ****");
  //   await planController.deleteStream(1);
  //   console.log("**** STREAM DELETED ****");
  //
  //   await spitout();
  //
  //   await delay(22000);
  //   // await delay(169198);
  //   await spitout();
  //
  //   await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
  //   console.log("**** Provider Withdrawal **** ");
  //
  //   await spitout();
  //
  //   await planController.connect(addr1).withdrawInterest(0);
  //   console.log("**** Interest Withdrawal ****");
  //
  //   await spitout();
  //
  //   await planController.connect(addr2).withdrawInterest(1);
  //   console.log("**** Interest Withdrawal 2 ****");
  //
  //   await spitout();
  //
  //   console.log("Flow: " + await planController.getFlowRate(DAI_KOVAN_ADDRESS));
  // });

  it("Test full process", async function() {
    this.timeout(50000);

    await planController.connect(addr1).createSubscription(DAI_KOVAN_ADDRESS);
    await planController.connect(addr2).createSubscription(DAI_KOVAN_ADDRESS);
    await daiContract.connect(addr1).approve(planController.address, await daiContract.balanceOf(addr1.address));
    await daiContract.connect(addr2).approve(planController.address, await daiContract.balanceOf(addr2.address));
    await planController.connect(addr1).fundSubscription(0);
    await planController.connect(addr2).fundSubscription(1);
    // await daiContract.connect(addr1).transfer(addr2.address, await daiContract.balanceOf(addr1.address));
    // await daiContract.connect(addr1).transfer(await planController.userPool(), await daiContract.balanceOf(addr1.address));
    await planController.connect(addr1).testDepositExtra(DAI_KOVAN_ADDRESS, await daiContract.balanceOf(addr1.address));
    await planController.connect(addr2).testDepositExtra(DAI_KOVAN_ADDRESS, await daiContract.balanceOf(addr2.address));
    let providerPoolAddress = await planController.providerPool();
    let subscriberStruct = await planController.subUsers(0);

    async function spitout() {
      console.log("PPL_DAIX: " + await pDaiXContract.balanceOf(providerPoolAddress));
      console.log("USW_DAIX: " + await pDaiXContract.balanceOf(subscriberStruct.userStreamWallet));
      console.log("OWNR_DAI: " + await daiContract.balanceOf(owner.address));
      console.log("ADR1_DAI: " + await daiContract.balanceOf(addr1.address));
      console.log("ADR2_DAI: " + await daiContract.balanceOf(addr2.address));
      console.log("UPL_ADAI: " + await aDaiContract.balanceOf(await planController.userPool()));
      console.log("PDAIX_TS: " + await pDaiXContract.totalSupply());
    };

    await spitout();
    await delay(50000);

    await spitout();

    await providerWithdrawal(DAI_KOVAN_ADDRESS);

    await spitout();


    console.log("Experiment START");

    // await withdrawInterest(addr1, 0);
    await planController.connect(addr1).withdrawInterest(0);
    console.log("**** Interest Withdrawal ****");

    await spitout();

    await withdrawInterest(addr1, 0);

    await spitout();

    console.log("Experiment END");

    // for (i = 0; i < 25; i++) {
    //   await time.increase(2);
    //   await planController.connect(addr1).withdrawInterest(0);
    // }


    await delay(50000);
    // await delay(169198);
    await spitout();

    await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
    console.log("**** Provider Withdrawal **** ");

    await spitout();

    await planController.connect(addr1).withdrawInterest(0);
    console.log("**** Interest Withdrawal ****");

    await spitout();

    await delay(50000);
    // await delay(169198);
    await spitout();

    await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
    console.log("**** Provider Withdrawal **** ");

    await spitout();

    await planController.connect(addr1).withdrawInterest(0);
    console.log("**** Interest Withdrawal ****");

    await spitout();

    await delay(22000);
    // await delay(169198);
    await spitout();

    await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
    console.log("**** Provider Withdrawal **** ");

    await spitout();

    await planController.connect(addr1).withdrawInterest(0);
    console.log("**** Interest Withdrawal ****");

    await spitout();

    await planController.deleteStream(0);
    console.log("**** STREAM DELETED ****");
    await planController.deleteStream(1);
    console.log("**** STREAM DELETED ****");

    await spitout();

    await delay(22000);
    // await delay(169198);
    await spitout();

    await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
    console.log("**** Provider Withdrawal **** ");

    await spitout();

    await planController.connect(addr1).withdrawInterest(0);
    console.log("**** Interest Withdrawal ****");

    await spitout();

    await planController.connect(addr2).withdrawInterest(1);
    console.log("**** Interest Withdrawal 2 ****");

    await spitout();

    console.log("Flow: " + await planController.getFlowRate(DAI_KOVAN_ADDRESS));
  });
})

async function delay(nSeconds) {
  await time.increase(nSeconds);
  console.log("**** Time increase " + nSeconds + " seconds ****");
};
