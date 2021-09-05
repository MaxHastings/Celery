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
    await Stake.bind(this)(100000000, 31536000);

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
  async function Stake(amount, time) {
    // Increase Stake
    await this.Celery.IncreaseStake(amount);

    // Test if account status is staking
    expect(
      (await this.Celery.getStatus(this.owner.address)).toString()
    ).to.equal("1");

    // Wait seconds in block time
    await hre.network.provider.send("evm_increaseTime", [time]);

    // Start payout
    await this.Celery.StartPayout();

    // Test if account status is payout
    expect(
      (await this.Celery.getStatus(this.owner.address)).toString()
    ).to.equal("0");
  }

  // Test case
  it("Test if payout is half amount in a year", async function () {
    await Stake.bind(this)(100000000, 31536000);

    // Wait half year in block time
    await hre.network.provider.send("evm_increaseTime", [15768000]);

    // Collect Payout for half year
    await this.Celery.CollectPayout();

    // Test if account status is payuot
    expect(
      (await this.Celery.getStatus(this.owner.address)).toString()
    ).to.equal("0");

    // Test if account staked balance is halved
    expect(
      (await this.Celery.getStakedAmount(this.owner.address)).toString()
    ).to.equal("100000000");

    // Test if payout was added to account balance
    expect(
      (await this.Celery.balanceOf(this.owner.address)).toString()
    ).to.equal("100000000");

    // Test if contract balance is subtracted
    expect(
      (await this.Celery.balanceOf(this.Celery.address)).toString()
    ).to.equal("0");
  });

  // Test case
  it("Test if contract mints tokens on payout", async function () {
    await Stake.bind(this)(100000000, 63072000);

    // Test if account staked balance is 4x
    expect(
      (await this.Celery.getStakedAmount(this.owner.address)).toString()
    ).to.equal("400000000");

    // Wait 1 year in block time
    await hre.network.provider.send("evm_increaseTime", [31536000]);

    // Collect Payout
    await this.Celery.CollectPayout();

    // Test if account balance received all staked tokens
    expect(
      (await this.Celery.balanceOf(this.owner.address)).toString()
    ).to.equal("400000000");

    // Test if token total supply is 5x
    expect((await this.Celery.totalSupply()).toString()).to.equal("500000000");
    // Test if contract balance is holding initial stake
    expect(
      (await this.Celery.balanceOf(this.Celery.address)).toString()
    ).to.equal("100000000");
  });

  // Test case
  it("Test if contract penalizes immediate payout by 50%", async function () {
    await Stake.bind(this)(100000000, 31536000);

    // Test if account staked balance is 2x
    expect(
      (await this.Celery.getStakedAmount(this.owner.address)).toString()
    ).to.equal("200000000");

    // Collect Payout
    await this.Celery.CollectAll();

    // Test if account balance received 50% of staked tokens
    expect(
      (await this.Celery.balanceOf(this.owner.address)).toString()
    ).to.equal("100000000");
    // Test if account staked balance is set back to 0
    expect(
      (await this.Celery.getStakedAmount(this.owner.address)).toString()
    ).to.equal("0");

    // Test if contract balance is subtracted
    expect(
      (await this.Celery.balanceOf(this.Celery.address)).toString()
    ).to.equal("0");
  });
});
