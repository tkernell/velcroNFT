const { expect } = require("chai");

const precision = BigInt(1e18);
const DAI_KOVAN_ADDRESS = "0xff795577d9ac8bd7d90ee22b6c1703490b6512fd";
const SUBSCRIPTION_PRICE = BigInt(1) * precision;

describe("PlanController", function() {

  let planController;
  let daiContract;
  let owner, addr1, addr2;

  beforeEach(async function () {
    const DaiContract = await ethers.getContractFactory("ERC20");
    daiContract = await DaiContract.attach(DAI_KOVAN_ADDRESS);

    const PlanController = await ethers.getContractFactory("PlanController");
    planController = await PlanController.deploy(2);
    [owner, addr1, addr2] = await ethers.getSigners();
    await planController.deployed();
    await planController.approveToken(DAI_KOVAN_ADDRESS, SUBSCRIPTION_PRICE);
  });

  it("Should set deployer as owner", async function() {
    expect(await planController.owner()).to.equal(owner.address);
  });

  it("Should be able to approve token", async function() {
    expect(await planController.tokenIsActive(DAI_KOVAN_ADDRESS)).to.equal(true);
  });

  it("Should be able to mint NFT", async function() {
    await planController.connect(addr1).createSubscription(DAI_KOVAN_ADDRESS);
    await daiContract.connect(addr1).approve(planController.address, SUBSCRIPTION_PRICE);
    await planController.connect(addr1).fundSubscription(0);
  })
})
