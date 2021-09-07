// test/Celery.test.js
// Load dependencies
const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
const hre = require("hardhat");

var Celery;

const initialSupply = 100000000;

const YEAR_IN_SECONDS = 31536000;

// Start test Celery
describe("Celery", function () {
  before(async function () {
    this.CeleryFactory = await ethers.getContractFactory("Celery");
    this.owner = (await ethers.getSigners())[0];
  });

  beforeEach(async function () {
    Celery = await this.CeleryFactory.deploy(initialSupply);
    await Celery.deployed();
  });

  // Test case
  it("Test if start stake changes account status to staking", async function () {
    // Start Stake
    await Celery.StartStake();

    // Test if account status is staking
    await expectStatus(this.owner.address, 1);
  });

  // Test case
  it("Test if account defaults to payout status", async function () {
    // Test if account status is payout
    await expectStatus(this.owner.address, 0);
  });

  // Test case
  it("Test if Force Payout reverts when collecting more than staked balance", async function () {
    await expect(Celery.ForcePayout(100)).to.be.revertedWith(
      "Collect payout is larger than staked amount"
    );
  });

  // Test case
  it("Test Collect Payout 10 times in one year", async function () {
    // Stake token and double it over a year
    await StakeAmountForTime.bind(this)(100000000, 31536000);

    var stakedAmount = 200000000;
    await expectStakedAmount(this.owner.address, stakedAmount);
    var increments = 10;
    for (var i = 1; i <= increments; i++) {
      await increaseBlockTime((1 / increments) * 31536000);
      await Celery.CollectPayout();

      // Calculate amount paid out
      const incrementalAmount = (i / increments) * stakedAmount;
      // Staked amount should decrease by incremental amount
      await expectStakedAmount(
        this.owner.address,
        stakedAmount - incrementalAmount
      );
      // Account balance should increase by incremental amount
      await expectAccountBalance(this.owner.address, incrementalAmount);
    }

    await expectStakedAmount(this.owner.address, 0);
    await expectAccountBalance(this.owner.address, 200000000);
    // Test if account status is payout
    await expectStatus(this.owner.address, 0);
    // Test if last process time increased
    await expectLastProcessedTime(this.owner.address, await getLastBlockTime());
  });

  // Test case
  it("Test increase stake 10 times in one year", async function () {
    var increments = 10;
    var increaseStakeAmount = initialSupply / increments;
    await Celery.IncreaseStake(increaseStakeAmount);
    var stakedAmount = increaseStakeAmount;
    await expectStakedAmount(this.owner.address, increaseStakeAmount);

    for (var i = 1; i < increments; i++) {
      const increaseTime = (1 / increments) * 31536000;
      await increaseBlockTime(increaseTime);
      await Celery.IncreaseStake(increaseStakeAmount);

      // Calculate new staked amouont
      stakedAmount =
        calculateStake(stakedAmount, increaseTime) + increaseStakeAmount;
      // Staked amount should increase by staked + interest + stake added
      await expectStakedAmount(this.owner.address, stakedAmount);

      // Account balance should decrease incrementally
      await expectAccountBalance(
        this.owner.address,
        initialSupply - increaseStakeAmount * (i + 1)
      );
    }
    // Test if account status is staking
    await expectStatus(this.owner.address, 1);
    // Test if last process time increased
    await expectLastProcessedTime(this.owner.address, await getLastBlockTime());
  });

  // Test case
  it("Test if staking amount doubles in a year", async function () {
    await StakeAmountForTime.bind(this)(100000000, 31536000);

    // Test if account staking balance doubled
    await expectStakedAmount(this.owner.address, 200000000);

    // Test if account balance is 0
    await expectAccountBalance(this.owner.address, 0);
  });

  // Test case
  it("Test if payout is half amount in a year", async function () {
    await StakeAmountForTime.bind(this)(100000000, 31536000);

    // Wait half year in block time
    await increaseBlockTime(15768000);

    // Collect Payout for half year
    await Celery.CollectPayout();

    // Test if account status is payuot
    await expectStatus(this.owner.address, 0);

    // Test if account staked balance is halved
    await expectStakedAmount(this.owner.address, initialSupply);

    // Test if payout was added to account balance
    await expectAccountBalance(this.owner.address, 100000000);

    // Test if contract balance is subtracted
    await expectAccountBalance(Celery.address, 0);
  });

  // Test case
  it("Test if contract mints tokens on payout", async function () {
    await StakeAmountForTime.bind(this)(100000000, 63072000);

    // Test if account staked balance is 4x
    await expectStakedAmount(this.owner.address, 400000000);

    // Wait 1 year in block time
    await increaseBlockTime(31536000);

    // Collect Payout
    await Celery.CollectPayout();

    // Test if account balance received all staked tokens
    await expectAccountBalance(this.owner.address, 400000000);

    // Test if token total supply is 5x
    await expectTotalSupply(500000000);
    // Test if contract balance is holding initial stake
    await expectAccountBalance(Celery.address, 100000000);
  });

  // Test case
  it("Test if contract penalizes immediate payout by 50%", async function () {
    await StakeAmountForTime.bind(this)(100000000, 31536000);

    // Test if account staked balance is 2x
    await expectStakedAmount(this.owner.address, 200000000);

    // Wait half a year
    await increaseBlockTime(15768000);

    // Collect a force payout for entire staked payout
    await Celery.ForcePayout(200000000);

    // Test if account balance received 75% of staked tokens. Half of tokens penalized by 50% and half not penalized
    await expectAccountBalance(this.owner.address, 150000000);

    // Test if account staked balance is set back to 0
    await expectStakedAmount(this.owner.address, 0);

    // Test if contract balance is subtracted
    await expectAccountBalance(Celery.address, 0);
  });

  // Test case
  it("Test if contract gives back no more than entire staked amount%", async function () {
    await StakeAmountForTime.bind(this)(100000000, 31536000);

    // Test if account staked balance is 2x
    await expectStakedAmount(this.owner.address, 200000000);

    // Wait 10 years
    await increaseBlockTime(31536000 * 10);

    // Collect Payout
    await Celery.CollectPayout();

    // Test if account balance received all staked tokens
    await expectAccountBalance(this.owner.address, 200000000);
    // Test if account staked balance is set back to 0
    await expectStakedAmount(this.owner.address, 0);
  });

  // Test case
  it("Test start stake twice", async function () {
    // Start Stake
    await Celery.StartStake();

    // Start Stake
    await Celery.StartStake();

    // Test if accuont status is staking
    await expectStatus(this.owner.address, 1);
  });

  // Test case
  it("Test collect with nothing staked", async function () {
    // Collect Payout
    await Celery.CollectPayout();
    // Test if account staked balance still 0
    await expectStakedAmount(this.owner.address, 0);

    // Test that account status is in payout
    await expectStatus(this.owner.address, 0);

    // Test if account balance still has same number of tokens
    await expectAccountBalance(this.owner.address, 100000000);
  });

  // Test case staking event
  it("Test Staking event is emitted", async function () {
    await expect(Celery.IncreaseStake(1000))
      .to.emit(Celery, "IncreaseStakeEvent")
      .withArgs(this.owner.address, 1000);
  });

  // Test case collect event
  it("Test Collect event is emitted", async function () {
    await StakeAmountForTime.bind(this)(1000, YEAR_IN_SECONDS);

    await increaseBlockTime(YEAR_IN_SECONDS);

    await expect(Celery.CollectPayout())
      .to.emit(Celery, "CollectPayoutEvent")
      .withArgs(this.owner.address, 2000);
  });

  // Test case force payout event
  it("Test Force Payout event is emitted", async function () {
    await StakeAmountForTime.bind(this)(1000, YEAR_IN_SECONDS);

    // Wait half year
    await increaseBlockTime(YEAR_IN_SECONDS / 2);

    await expect(Celery.ForcePayout(2000))
      .to.emit(Celery, "ForcePayoutEvent")
      .withArgs(this.owner.address, 500);
  });

  // Test case account status event
  it("Test Account Status event is emitted on Increase Stake", async function () {
    await expect(Celery.IncreaseStake(1000))
      .to.emit(Celery, "AccountStatusEvent")
      .withArgs(this.owner.address, 1);
  });

  // Test case account status event
  it("Test Account Status event is emitted on Start Stake", async function () {
    await expect(Celery.StartStake())
      .to.emit(Celery, "AccountStatusEvent")
      .withArgs(this.owner.address, 1);
  });

  // Test case account status event
  it("Test Account Status event is emitted on Force Payout", async function () {
    await Celery.IncreaseStake(1000);

    await expect(Celery.ForcePayout(1000))
      .to.emit(Celery, "AccountStatusEvent")
      .withArgs(this.owner.address, 0);
  });

  // Test case account status event
  it("Test Account Status event is emitted on Start Payout", async function () {
    await Celery.IncreaseStake(1000);

    await expect(Celery.StartPayout())
      .to.emit(Celery, "AccountStatusEvent")
      .withArgs(this.owner.address, 0);
  });
});

// *** Helper Functions *** //

// Helper function for account staking of time length
async function StakeAmountForTime(amount, time) {
  // Increase Stake
  await Celery.IncreaseStake(amount);

  const timeStaked = await Celery.getLastProcessedTime(this.owner.address);

  // Test if account status is staking
  await expectStatus(this.owner.address, 1);

  // Wait seconds in block time
  await increaseBlockTime(time);

  // Start payout
  await Celery.StartPayout();

  // Test if last processed time is correct
  expectLastProcessedTime(
    this.owner.address,
    BigNumber.from(time).add(timeStaked)
  );

  // Test if account status is payout
  await expectStatus(this.owner.address, 0);

  // Test current payout amount is correct
  const calcStakeAmount = calculateStake(amount, time);
  await expectPayoutAmount(this.owner.address, calcStakeAmount);

  // Test staked amount is correct
  await expectStakedAmount(this.owner.address, calcStakeAmount);
}

function calculateStake(amount, stakedTime) {
  const secondsInAYear = 31536000;
  const percTime = stakedTime / secondsInAYear;
  return Math.ceil(amount * Math.pow(Math.E, percTime * Math.LN2));
}

// *** Expect Functions *** //

async function expectAccountBalance(address, amount) {
  expect((await Celery.balanceOf(address)).toString()).to.equal(
    amount.toString()
  );
}

async function expectStakedAmount(address, amount) {
  expect((await Celery.getStakedAmount(address)).toString()).to.equal(
    amount.toString()
  );
}

async function expectPayoutAmount(address, amount) {
  expect((await Celery.getCurrentPayoutAmount(address)).toString()).to.equal(
    amount.toString()
  );
}

async function expectLastProcessedTime(address, time) {
  expect((await Celery.getLastProcessedTime(address)).toString()).to.equal(
    time.toString()
  );
}

async function expectStatus(address, status) {
  expect((await Celery.getStatus(address)).toString()).to.equal(
    status.toString()
  );
}

async function expectTotalSupply(amount) {
  expect((await Celery.totalSupply()).toString()).to.equal(amount.toString());
}

async function getLastBlockTime() {
  return (await ethers.provider.getBlock("latest")).timestamp;
}

// Increase block timestamp by number of seconds
async function increaseBlockTime(time) {
  const lastBlockTime = await getLastBlockTime();
  const nextBlockTime = lastBlockTime + time - 1;
  await hre.network.provider.send("evm_mine", [nextBlockTime]);
}
