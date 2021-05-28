const { expect } = require("chai");
const { time } = require("@openzeppelin/test-helpers");

const precision = BigInt(1e18);
const DAI_KOVAN_ADDRESS = "0xff795577d9ac8bd7d90ee22b6c1703490b6512fd";
const AAVE_BRIDGE_ADDRESS = "0x4922EEBff2D2d82dd112B1D662Fd72B948a3C16E";
const SUBSCRIPTION_PRICE = BigInt(2) * precision;
const NDAYS = 2;



describe("PlanFactory", function() {

  let planFactory;
  let planControllerLogic;
  let planController;
  let owner, addr1, addr2, addr3;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const PlanController = await ethers.getContractFactory("PlanController");
    planControllerLogic = await PlanController.deploy();
    await planControllerLogic.deployed();

    const PlanFactory = await ethers.getContractFactory("PlanFactory");
    planFactory = await PlanFactory.deploy(planControllerLogic.address);
    await planFactory.deployed();

    await planFactory.updateFeePercentage(500);

    await planFactory.createPlan(NDAYS);
    let planControllerAddress = await planFactory.plans(0);

    planController = await PlanController.attach(planControllerAddress);
    await planController.approveToken(DAI_KOVAN_ADDRESS, SUBSCRIPTION_PRICE);

    const ERC20Contract = await ethers.getContractFactory("ERC20");
    daiContract = await ERC20Contract.attach(DAI_KOVAN_ADDRESS);


  })

  it("Test deployment", async function() {

    await planController.connect(addr1).createSubscription(DAI_KOVAN_ADDRESS);
    await daiContract.connect(addr1).approve(planController.address, await daiContract.balanceOf(addr1.address));
    await planController.connect(addr1).fundSubscription(0);

    await time.increase(10000);

    await planController.providerWithdrawal(DAI_KOVAN_ADDRESS);
    await planController.connect(addr1).withdrawInterest(0);


  })



})
