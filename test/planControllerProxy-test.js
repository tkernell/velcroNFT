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
  let owner, addr1, addr2, addr3;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const PlanController = await ethers.getContractFactory("PlanController");
    planControllerLogic = await PlanController.deploy();
    await planControllerLogic.deployed();

    const PlanFactory = await ethers.getContractFactory("PlanFactory");
    planFactory = await PlanFactory.deploy(planControllerLogic.address);
    await planFactory.deployed();


  })

  it("Test deployment", async function() {
    await planFactory.createPlan(NDAYS);
  })



})
