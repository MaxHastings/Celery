// test/Celery.test.js
// Load dependencies
const { expect } = require("chai");
const hre = require("hardhat");

// Start test Celery
describe("Celery", function () {
  before(async function () {
    this.CeleryFactory = await ethers.getContractFactory("Celery");
    this.owner = (await ethers.getSigners())[0];
  });

  beforeEach(async function () {
    this.Celery = await this.CeleryFactory.deploy(100000000);
    await this.Celery.deployed();
  });

  // Test case
  it("Test if start stake changes account status to staking", async function () {
    // Start Stake
    await this.Celery.StartStake();

    // Test if account status is staking
    expect(
      (await this.Celery.getStatus(this.owner.address)).toString()
    ).to.equal("1");
  });

  // Test case
  it("Test if staking amount doubles in a year", async function () {
    // Increase Stake
    await this.Celery.IncreaseStake(100000000);

    // Wait 1 year in block time
    await hre.network.provider.send("evm_increaseTime", [31536000]);

    // Start payout
    await this.Celery.StartPayout();

    // Test if account staking balance doubled
    expect(
      (await this.Celery.getStakedAmount(this.owner.address)).toString()
    ).to.equal("200000000");
  });
});
