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
    await DoubleStakedAmount.bind(this)();

    // Test if account staking balance doubled
    expect(
      (await this.Celery.getStakedAmount(this.owner.address)).toString()
    ).to.equal("200000000");

    // Test if account balance is 0
    expect(
      (await this.Celery.balanceOf(this.owner.address)).toString()
    ).to.equal("0");
  });

  // Helper function for account staking for 1 year and doubling staked amount
  async function DoubleStakedAmount() {
    // Increase Stake
    await this.Celery.IncreaseStake(100000000);

    // Wait 1 year in block time
    await hre.network.provider.send("evm_increaseTime", [31536000]);

    // Start payout
    await this.Celery.StartPayout();
  }

  // Test case
  it("Test if payout is half amount in a year", async function () {
    await DoubleStakedAmount.bind(this)();

    // Wait half year in block time
    await hre.network.provider.send("evm_increaseTime", [15768000]);

    // Collect Payout for half year
    await this.Celery.CollectPayout();

    // Test if account staked balance is halved
    expect(
      (await this.Celery.getStakedAmount(this.owner.address)).toString()
    ).to.equal("100000000");

    // Test if payout was added to account balance
    expect(
      (await this.Celery.balanceOf(this.owner.address)).toString()
    ).to.equal("100000000");
  });
});
