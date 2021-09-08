// test/Celery.test.js
// Load dependencies
const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
const hre = require("hardhat");

var Celery;

const YEAR_IN_SECONDS = 31536000;

describe("Test Celery reverts", function () {
  var initialSupply = 1000;

  before(async function () {
    this.CeleryFactory = await ethers.getContractFactory("Celery");
    this.owner = (await ethers.getSigners())[0];
  });

  beforeEach(async function () {
    Celery = await this.CeleryFactory.deploy(initialSupply);
    await Celery.deployed();
  });

  // Test case
  it("Test if Force Payout reverts when collecting more than staked balance", async function () {
    await expect(Celery.ForcePayout(100)).to.be.revertedWith(
      "Collect payout is larger than Account balance"
    );
  });

  // Test case
  it("Test if Increase Balance with zero reverts", async function () {
    await expect(Celery.IncreaseBalanceAndStake(0)).to.be.revertedWith(
      "Value must be greater than zero."
    );
  });
});

describe("Test Celery staking", function () {
  var initialSupply = 1000;

  before(async function () {
    this.CeleryFactory = await ethers.getContractFactory("Celery");
    this.owner = (await ethers.getSigners())[0];
  });

  beforeEach(async function () {
    Celery = await this.CeleryFactory.deploy(initialSupply);
    await Celery.deployed();
  });

  // Test case staking event
  it("Test increase balance and stake event is emitted", async function () {
    await expect(Celery.IncreaseBalanceAndStake(1000))
      .to.emit(Celery, "IncreaseBalanceAndStakeEvent")
      .withArgs(this.owner.address, 1000);
  });

  // Test case account status event
  it("Test Account Status event is emitted on Increase Stake", async function () {
    await expect(Celery.IncreaseBalanceAndStake(1000))
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
    await Celery.IncreaseBalanceAndStake(1000);

    await expect(Celery.ForcePayout(1000))
      .to.emit(Celery, "AccountStatusEvent")
      .withArgs(this.owner.address, 0);
  });

  // Test case account status event
  it("Test Account Status event is emitted on Start Payout", async function () {
    await Celery.IncreaseBalanceAndStake(1000);

    await expect(Celery.StartPayout())
      .to.emit(Celery, "AccountStatusEvent")
      .withArgs(this.owner.address, 0);
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
  it("Test increase stake 10 times in one year", async function () {
    var increments = 10;
    var increaseStakeAmount = initialSupply / increments;
    await Celery.IncreaseBalanceAndStake(increaseStakeAmount);
    var stakedAmount = increaseStakeAmount;
    await expectAccountAmount(this.owner.address, increaseStakeAmount);

    for (var i = 1; i < increments; i++) {
      const increaseTime = (1 / increments) * 31536000;
      await increaseBlockTime(increaseTime);
      await Celery.IncreaseBalanceAndStake(increaseStakeAmount);

      // Calculate new staked amouont
      stakedAmount =
        calculateStake(stakedAmount, increaseTime) + increaseStakeAmount;
      // Account amount should increase by staked + interest + stake added
      await expectAccountAmount(this.owner.address, stakedAmount);

      // Token balance should decrease incrementally
      await expectTokenBalance(
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
    await Celery.IncreaseBalanceAndStake(initialSupply);

    await increaseBlockTime(YEAR_IN_SECONDS);

    await Celery.StartPayout();

    // Test if account staking balance doubled
    await expectAccountAmount(this.owner.address, initialSupply * 2);

    // Test if token balance is 0
    await expectTokenBalance(this.owner.address, 0);
  });

  // Test case
  it("Test if contract gives back no more than entire staked amount%", async function () {
    await Celery.IncreaseBalanceAndStake(initialSupply);

    var stakeLength = YEAR_IN_SECONDS * 10;
    // Wait 10 years
    await increaseBlockTime(stakeLength);

    await Celery.StartPayout();

    // Wait 10 years
    await increaseBlockTime(YEAR_IN_SECONDS * 10);

    await Celery.CollectPayout();
    // Test if owner token balance received all staked tokens
    await expectTokenBalance(
      this.owner.address,
      calculateStake(initialSupply, stakeLength)
    );
    // Test if account staked balance is set back to 0
    await expectAccountAmount(this.owner.address, 0);
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
    await expectAccountAmount(this.owner.address, 0);

    // Test that account status is in payout
    await expectStatus(this.owner.address, 0);

    // Test if owner token balance still has same number of tokens
    await expectTokenBalance(this.owner.address, initialSupply);
  });

  // Test case
  it("Test if contract mints tokens on payout", async function () {
    await Celery.IncreaseBalanceAndStake(initialSupply);

    var stakedLength = YEAR_IN_SECONDS * 10;
    // Wait 10 years in block time
    await increaseBlockTime(stakedLength);

    await Celery.StartPayout();

    await increaseBlockTime(YEAR_IN_SECONDS);

    // Collect Payout
    await Celery.CollectPayout();

    // Test if total token supply increased
    await expectTotalSupply(
      initialSupply + calculateStake(initialSupply, stakedLength)
    );

    // Test if contract token balance is still holding tokens
    await expectTokenBalance(Celery.address, initialSupply);
  });
});

describe("Test Celery payouts", function () {
  var initialSupply = 1000;

  before(async function () {
    this.CeleryFactory = await ethers.getContractFactory("Celery");
    this.owner = (await ethers.getSigners())[0];
  });

  beforeEach(async function () {
    Celery = await this.CeleryFactory.deploy(500);
    await Celery.deployed();

    await Celery.IncreaseBalanceAndStake(500);

    await increaseBlockTime(YEAR_IN_SECONDS);

    await Celery.StartPayout();

    // Should have 1000 tokens in Account Balance before each of the following tests run
  });

  it("Test if last staked balance is correect", async function () {
    await expectLastStakedBalance(this.owner.address, initialSupply);
  });

  // Test case
  it("Test if payout is half amount in a year", async function () {
    // Wait half year in block time
    await increaseBlockTime(YEAR_IN_SECONDS / 2);

    // Collect Payout for half year
    await Celery.CollectPayout();

    // Test if account staked balance is halved
    await expectAccountAmount(this.owner.address, initialSupply / 2);

    // Test if payout was added to token balance
    await expectTokenBalance(this.owner.address, initialSupply / 2);
  });

  // Test case
  it("Test if contract penalizes immediate payout by 50%", async function () {
    // Wait half a year
    await increaseBlockTime(YEAR_IN_SECONDS / 2);

    // Collect a force payout for entire staked payout
    await Celery.ForcePayout(initialSupply);

    // Test if ownre token balance received 75% of staked tokens. Half of tokens penalized by 50% and half not penalized
    await expectTokenBalance(this.owner.address, initialSupply * 0.75);

    // Test if account staked balance is set back to 0
    await expectAccountAmount(this.owner.address, 0);

    // Test if contract token balance is subtracted
    await expectTokenBalance(Celery.address, 0);
  });

  // Test case collect event
  it("Test Collect event is emitted", async function () {
    await increaseBlockTime(YEAR_IN_SECONDS);

    await expect(Celery.CollectPayout())
      .to.emit(Celery, "CollectPayoutEvent")
      .withArgs(this.owner.address, 1000);
  });

  // Test case force payout event
  it("Test Force Payout event is emitted", async function () {
    // Wait half year
    await increaseBlockTime(YEAR_IN_SECONDS / 2);

    await expect(Celery.ForcePayout(1000))
      .to.emit(Celery, "ForcePayoutEvent")
      .withArgs(this.owner.address, 250);
  });

  // Test case
  it("Test Collect Payout 10 times in one year", async function () {
    var stakedAmount = 1000;
    var increments = 10;
    for (var i = 1; i <= increments; i++) {
      await increaseBlockTime((1 / increments) * 31536000);
      await Celery.CollectPayout();

      // Calculate amount paid out
      const incrementalAmount = (i / increments) * stakedAmount;
      // Account amount should decrease by incremental amount
      await expectAccountAmount(
        this.owner.address,
        stakedAmount - incrementalAmount
      );
      // Token balance should increase by incremental amount
      await expectTokenBalance(this.owner.address, incrementalAmount);
    }

    await expectAccountAmount(this.owner.address, 0);
    await expectTokenBalance(this.owner.address, stakedAmount);
    // Test if account status is payout
    await expectStatus(this.owner.address, 0);
    // Test if last process time increased
    await expectLastProcessedTime(this.owner.address, await getLastBlockTime());
  });

  // Test case
  it("Test if Force Payout has no penalty if payout period is over", async function () {
    await increaseBlockTime(YEAR_IN_SECONDS);

    await Celery.ForcePayout(1000);

    await expectTokenBalance(this.owner.address, 1000);
  });
});

// *** Helper Functions *** //

function calculateStake(amount, stakedTime) {
  const secondsInAYear = 31536000;
  const percTime = stakedTime / secondsInAYear;
  return Math.ceil(amount * Math.pow(Math.E, percTime * Math.LN2));
}

// *** Expect Functions *** //

async function expectTokenBalance(address, amount) {
  expect((await Celery.balanceOf(address)).toString()).to.equal(
    amount.toString()
  );
}

async function expectAccountAmount(address, amount) {
  expect((await Celery.getStakedAmount(address)).toString()).to.equal(
    amount.toString()
  );
}

async function expectLastStakedBalance(address, amount) {
  expect((await Celery.getLastStakingBalance(address)).toString()).to.equal(
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
