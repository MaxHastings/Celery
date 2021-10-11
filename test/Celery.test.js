// test/Celery.test.js
// Load dependencies
const { expect } = require("chai");
const hre = require("hardhat");
/* global describe,before,beforeEach,it,ethers */

var Celery;

const SECONDS_IN_A_YEAR = 31536000;

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

    it("Test if Force Payout reverts when collecting more than account balance", async function () {
        await expect(Celery.forcePayout(100, 1)).to.be.revertedWith(
            "Insufficient account balance"
        );
    });

    it("Test if Increase Balance with zero reverts", async function () {
        await expect(Celery.increaseBalanceAndStake(0)).to.be.revertedWith(
            "Amount must be greater than 0."
        );
    });

    // Test case
    it("Test start stake twice reverts", async function () {
        // Start Stake
        await Celery.startStake();

        // Start Stake again
        await expect(Celery.startStake()).to.be.revertedWith(
            "Account already staking."
        );
    });

    // Test case
    it("Test start payout when already in payout reverts", async function () {
        // Start Payout
        await expect(Celery.startPayout()).to.be.revertedWith(
            "Account already in payout."
        );
    });

    it("Test collect payout with nothing in account balance", async function () {
        // Collect Payout
        await expect(Celery.collectPayout()).to.be.revertedWith(
            "Nothing to payout."
        );
    });

    it("Test collect payout when account is staking reverts", async function () {
        // Start Stake
        await Celery.startStake();

        // Collect Payout
        await expect(Celery.collectPayout()).to.be.revertedWith(
            "Account is staking."
        );
    });

    it("Test if force payout with zero reverts", async function () {
        await expect(Celery.forcePayout(0, 1)).to.be.revertedWith(
            "Amount must be greater than 0."
        );
    });

    it("Test if estimate payout reverts when in stake status", async function () {
        // Start Stake
        await Celery.startStake();

        await expect(Celery.estimateCollectPayout(this.owner.address, 1)).to.be.revertedWith(
            "Account is staking."
        );
    });

    it("Test if estimate payout reverts when less than time snapshot", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        // Subtract half a year;
        const tooEarly = await getLastBlockTime() - 1;

        await Celery.startPayout();

        await expect(Celery.estimateCollectPayout(this.owner.address, tooEarly)).to.be.revertedWith(
            "Timestamp too early."
        );
    });

    it("Test if estimate stake reverts when in payout status", async function () {
        await expect(Celery.estimateStakeBalance(this.owner.address, 1)).to.be.revertedWith(
            "Account is in payout."
        );
    });

    it("Test if estimate stake reverts when less than time snapshot", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        // Subtract half a year;
        const tooEarly = await getLastBlockTime() - 1;

        await expect(Celery.estimateStakeBalance(this.owner.address, tooEarly)).to.be.revertedWith(
            "Timestamp too early."
        );
    });

    it("Test if estimate of force payout penalty reverts on too high of amount", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        await Celery.startPayout();

        // Pass by half a year;
        const halfYearLater = await getLastBlockTime() + 15768000;

        // -1 added due to rounding errors when dealing with such small numbers over the course of a year (and stake does a ceil call)
        await expect(Celery.estimateForcePayoutPenaltyFee(this.owner.address, initialSupply, 0, halfYearLater)).to.be.revertedWith(
            "Insufficient account balance."
        );
    });

    it("Test if estimate of force payout penalty reverts on amount = 0", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        await Celery.startPayout();

        // -1 added due to rounding errors when dealing with such small numbers over the course of a year (and stake does a ceil call)
        await expect(Celery.estimateForcePayoutPenaltyFee(this.owner.address, 0, 0, 0)).to.be.revertedWith(
            "Amount must be greater than 0."
        );
    });

    it("Test if estimate force payout reverts when less than time snapshot", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        // Subtract half a year;
        const tooEarly = await getLastBlockTime() - 1;

        await expect(Celery.estimateForcePayoutPenaltyFee(this.owner.address, initialSupply, 1, tooEarly)).to.be.revertedWith(
            "Timestamp too early."
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

    it("Test staking with 0 account balance", async function () {

        await Celery.startStake();

        await Celery.startPayout();

        await expectAccountAmount(this.owner.address, 0);

    });

    it("Test interest end time", async function () {
        var blockTime = await getLastBlockTime();
        var endTime = blockTime + (186 * SECONDS_IN_A_YEAR);

        // Check expected end time is correct
        await expectEndInterestTime(endTime);

        await Celery.increaseBalanceAndStake(1000);

        // wait 1000 years staking
        var wait = 1000 * SECONDS_IN_A_YEAR;

        await increaseBlockTime(wait);

        // If this runs without revert then there is no overflow
        await Celery.startPayout();

        // Increase Stake should not cause seconds staked underflow
        await Celery.increaseBalanceAndStake(1000);
    });

    it("Test increase balance and stake event is emitted", async function () {
        await expect(Celery.increaseBalanceAndStake(1000))
            .to.emit(Celery, "IncreaseBalanceAndStakeEvent")
            .withArgs(this.owner.address, 1000);
    });

    it("Test Account Status event with staking is emitted on Increase Stake", async function () {
        await expect(Celery.increaseBalanceAndStake(1000))
            .to.emit(Celery, "AccountStatusEvent")
            .withArgs(this.owner.address, 1);
    });

    it("Test Account Status event with staking is emitted with staking on Start Stake", async function () {
        await expect(Celery.startStake())
            .to.emit(Celery, "AccountStatusEvent")
            .withArgs(this.owner.address, 1);
    });

    it("Test Account Status event with payout is emitted on Force Payout", async function () {
        await Celery.increaseBalanceAndStake(1000);

        await expect(Celery.forcePayout(1000, 1))
            .to.emit(Celery, "AccountStatusEvent")
            .withArgs(this.owner.address, 0);
    });

    it("Test Account Status event with payout is emitted on Start Payout", async function () {
        await Celery.increaseBalanceAndStake(1000);

        await expect(Celery.startPayout())
            .to.emit(Celery, "AccountStatusEvent")
            .withArgs(this.owner.address, 0);
    });

    it("Test if start stake changes account status to staking", async function () {
        // Start Stake
        await Celery.startStake();

        // Test if account status is staking
        await expectStatus(this.owner.address, 1);
        // Test if last process time is updated
        await expectLastProcessedTime(this.owner.address, await getLastBlockTime());
    });

    it("Test if increase balance and stake changes account status to staking", async function () {
        // Increase Stake
        await Celery.increaseBalanceAndStake(1000);

        // Test if account status is staking
        await expectStatus(this.owner.address, 1);
        // Test if last process time is updated
        await expectLastProcessedTime(this.owner.address, await getLastBlockTime());
    });

    it("Test if account defaults to payout status", async function () {

        // Test if account status is payout by default
        await expectStatus(this.owner.address, 0);
    });

    it("Test if account switches to payout status on force payout", async function () {
        // Increase Stake
        await Celery.increaseBalanceAndStake(1000);

        await Celery.forcePayout(1000, 1);
        // Test if account status is payout
        await expectStatus(this.owner.address, 0);
        // Test if last process time is updated
        await expectLastProcessedTime(this.owner.address, await getLastBlockTime());
    });

    it("Test if account switches to payout status on start payout", async function () {
        // Increase Stake
        await Celery.increaseBalanceAndStake(1000);

        await Celery.startPayout();
        // Test if account status is payout
        await expectStatus(this.owner.address, 0);
        // Test if last process time is updated
        await expectLastProcessedTime(this.owner.address, await getLastBlockTime());
    });

    it("Test increase stake 10 times in one year", async function () {
        var increments = 10;
        var increaseStakeAmount = initialSupply / increments;
        await Celery.increaseBalanceAndStake(increaseStakeAmount);
        var stakedAmount = increaseStakeAmount;
        await expectAccountAmount(this.owner.address, increaseStakeAmount);
        const increaseTime = (1 / increments) * SECONDS_IN_A_YEAR;

        for (var i = 1; i < increments; i++) {
            await increaseBlockTime(increaseTime);
            await Celery.increaseBalanceAndStake(increaseStakeAmount);

            // Calculate new staked amouont
            stakedAmount =
                calculateStake(stakedAmount, increaseTime) + increaseStakeAmount;
            // Account amount should increase by staked + interest + stake added
            await expectAccountAmount(this.owner.address, stakedAmount);

            // Token balance should decrease
            await expectTokenBalance(
                this.owner.address,
                initialSupply - increaseStakeAmount * (i + 1)
            );
        }
    });

    it("Test if staking amount doubles in a year", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await Celery.startPayout();

        // Test if account staking balance doubled
        await expectAccountAmount(this.owner.address, initialSupply * 2);

        // Test if token balance is 0
        await expectTokenBalance(this.owner.address, 0);
    });

    it("Test if contract gives back no more than entire staked amount%", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        var stakeLength = SECONDS_IN_A_YEAR * 10;
        // Wait 10 years
        await increaseBlockTime(stakeLength);

        await Celery.startPayout();

        // Wait 10 years
        await increaseBlockTime(SECONDS_IN_A_YEAR * 10);

        await Celery.collectPayout();
        // Test if owner token balance received all staked tokens
        await expectTokenBalance(
            this.owner.address,
            calculateStake(initialSupply, stakeLength)
        );
        // Test if account staked balance is set back to 0
        await expectAccountAmount(this.owner.address, 0);
    });

    it("Test if contract mints tokens on payout", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        var stakedLength = SECONDS_IN_A_YEAR * 10;
        // Wait 10 years in block time
        await increaseBlockTime(stakedLength);

        await Celery.startPayout();

        await increaseBlockTime(SECONDS_IN_A_YEAR);

        // Collect Payout
        await Celery.collectPayout();

        // Test if total token supply increased
        await expectTotalSupply(
            calculateStake(initialSupply, stakedLength)
        );

        // Test if contract token balance is empty
        await expectTokenBalance(Celery.address, 0);
    });

    it("Test if estimate of future payout is accurate", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        // Pass by half a year;
        const halfYearLater = await getLastBlockTime() + 15768000;

        await Celery.startPayout();

        // +1 added due to rounding errors when dealing with such small numbers over the course of a year (and stake does a ceil call)
        await expect((await Celery.estimateCollectPayout(this.owner.address, halfYearLater)).toString()).to.equal(
            ((initialSupply * 0.5) + 1).toString()
        );
    });

    it("Test if estimate of future payout is accurate when well beyond a year", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        // Pass by year and a half;
        const yearAndHalfLater = await getLastBlockTime() + 47304000;

        await Celery.startPayout();

        // +1 added due to rounding errors when dealing with such small numbers over the course of a year (and stake does a ceil call)
        await expect((await Celery.estimateCollectPayout(this.owner.address, yearAndHalfLater)).toString()).to.equal(
            (initialSupply + 1).toString()
        );
    });

    it("Test if estimate of future stake balance is accurate", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        // Pass by half a year;
        const halfYear = 15768000;
        const halfYearLater = (await Celery.getLastProcessedTime(this.owner.address)).add(halfYear);

        await expect((await Celery.estimateStakeBalance(this.owner.address, halfYearLater.toString())).toString()).to.equal(
            calculateStake(initialSupply, halfYear).toString()
        );
    });

    it("Test if estimate of force payout penalty is accurate", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        await Celery.startPayout();

        // Pass by half a year;
        const halfYearLater = await getLastBlockTime() + 15768000;

        // Expected amount based on penalty of 50% (We take 50% first because that's what is unavaialble, and 50% of that would be the fee)
        const penaltyAmount = (initialSupply * 0.5) * 0.5;

        // -1 added due to rounding errors when dealing with such small numbers over the course of a year (and stake does a ceil call)
        await expect((await Celery.estimateForcePayoutPenaltyFee(this.owner.address, initialSupply, 1, halfYearLater)).toString()).to.equal(
            (penaltyAmount - 1).toString()
        );
    });

    it("Test if estimate of force payout penalty is accurate (TO_WALLET)", async function () {
        await Celery.increaseBalanceAndStake(initialSupply);

        await Celery.startPayout();

        // Pass by half a year;
        const halfYearLater = await getLastBlockTime() + 15768000;

        // Expected amount based on penalty of 50% (We take 50% first because that's what is unavaialble, and 50% of that would be the fee)
        const penaltyAmount = (initialSupply * 0.5) * 0.5;

        // -1 added due to rounding errors when dealing with such small numbers over the course of a year (and stake does a ceil call)
        // Our amount is 0.75, because we are using a TO_WALLET type, so amount is post-penalty value
        await expect((await Celery.estimateForcePayoutPenaltyFee(this.owner.address, initialSupply * 0.75, 0, halfYearLater)).toString()).to.equal(
            (penaltyAmount - 1).toString()
        );
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

        await Celery.increaseBalanceAndStake(500);

        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await Celery.startPayout();

        // Should have 1000 tokens in Account Balance before each of the following tests run
    });

    it("Test initial supply", async function () {
        await expectTotalStakingSupply(0);

        await expectTotalPayoutSupply(initialSupply);

        await expectFullyDilutedSupply(initialSupply);
    });

    it("Test supply after collect", async function () {

        await increaseBlockTime(SECONDS_IN_A_YEAR / 2);

        await Celery.collectPayout();

        await expectTotalStakingSupply(0);

        await expectTotalPayoutSupply(initialSupply / 2);

        await expectFullyDilutedSupply(initialSupply);
    });

    it("Test supply after force payout", async function () {

        await Celery.forcePayout(initialSupply / 2, 1);

        await expectTotalStakingSupply(0);

        await expectTotalPayoutSupply(initialSupply / 2);

        await expectFullyDilutedSupply(initialSupply * 0.75);

    });

    it("Test if last staked balance is correct", async function () {
        await expectLastStakedBalance(this.owner.address, initialSupply);
    });

    it("Test if payout is half amount in a year", async function () {
        // Wait half year in block time
        await increaseBlockTime(SECONDS_IN_A_YEAR / 2);

        // Collect Payout for half year
        await Celery.collectPayout();

        // Test if account staked balance is halved
        await expectAccountAmount(this.owner.address, initialSupply / 2);

        // Test if payout was added to token balance
        await expectTokenBalance(this.owner.address, initialSupply / 2);
    });

    it("Test if contract penalizes force payout by 50%", async function () {
        // Wait half a year
        await increaseBlockTime(SECONDS_IN_A_YEAR / 2);

        // Collect a force payout for entire account balance
        await Celery.forcePayout(initialSupply, 1);

        // Test if owner token balance received 75% of staked tokens. 
        // Half of tokens penalized by 50% and half not penalized since account spent half a year in payout.
        await expectTokenBalance(this.owner.address, initialSupply * 0.75);

        // Test if account staked balance is set back to 0
        await expectAccountAmount(this.owner.address, 0);

        // Test if contract token balance is subtracted
        await expectTokenBalance(Celery.address, 0);
    });

    it("Test if contract penalizes force payout by 50% (TO_WALLET)", async function () {
        // Wait half a year
        await increaseBlockTime(SECONDS_IN_A_YEAR / 2);

        // Collect a force payout for entire account balance (half of entire balance with the half year stake)
        await Celery.forcePayout(750, 0);

        // Test if owner token balance received 50% of staked tokens. 
        // Half of tokens penalized by 50% and half not penalized since account spent half a year in payout.
        await expectTokenBalance(this.owner.address, 750);

        // Test if account staked balance is set back to 0
        await expectAccountAmount(this.owner.address, 0);

        // Test if contract token balance is subtracted
        await expectTokenBalance(Celery.address, 0);
    });

    it("Test if force payout does no penalty when requested amount matches collect payout", async function () {
        // Wait half a year
        await increaseBlockTime(SECONDS_IN_A_YEAR / 2);

        // Collect a force payout for half of account balance
        await Celery.forcePayout(initialSupply / 2, 1);

        // Test if owner token balance received exact amount with no penalty
        await expectTokenBalance(this.owner.address, initialSupply / 2);

        // Test if account staked balance is set to half
        await expectAccountAmount(this.owner.address, initialSupply / 2);

        // Test if contract token balance is subtracted
        await expectTokenBalance(Celery.address, 0);
    });

    it("Test force payout of entire staked balance", async function () {
        // Collect a force payout for entire staked payout
        await Celery.forcePayout(initialSupply, 1);

        // Half of tokens penalized by 50%
        await expectTokenBalance(this.owner.address, initialSupply / 2);

        // Test if account staked balance is set back to 0
        await expectAccountAmount(this.owner.address, 0);
    });

    it("Test Account Status event with payout is emitted on Collect Payout", async function () {
        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await expect(Celery.collectPayout())
            .to.emit(Celery, "CollectPayoutEvent")
            .withArgs(this.owner.address, 1000);
    });

    it("Test Force Payout event is emitted", async function () {
        // Wait half year
        await increaseBlockTime(SECONDS_IN_A_YEAR / 2);

        await expect(Celery.forcePayout(1000, 1))
            .to.emit(Celery, "ForcePayoutEvent")
            .withArgs(this.owner.address, 250);
    });

    it("Test Collect Payout 10 times in one year", async function () {
        var stakedAmount = 1000;
        var increments = 10;
        var timeToIncrement = (1 / increments) * SECONDS_IN_A_YEAR;
        for (var i = 1; i <= increments; i++) {
            await increaseBlockTime(timeToIncrement);
            await Celery.collectPayout();

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
    });

    it("Test if Force Payout has no penalty if payout period is over", async function () {
        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await Celery.forcePayout(1000, 1);

        // Expect to receive full amount with no penalty since one year has passed.
        await expectTokenBalance(this.owner.address, 1000);
    });
});

describe("Test Celery Supply with multiple accounts", function () {
    var initialSupply = 1000;

    before(async function () {
        this.CeleryFactory = await ethers.getContractFactory("Celery");
        this.signers = await ethers.getSigners();
        this.user1 = this.signers[0];
        this.user2 = this.signers[1];
    });

    beforeEach(async function () {
        Celery = await this.CeleryFactory.deploy(initialSupply);
        await Celery.deployed();
        await Celery.transfer(this.user2.address, 500);
    });

    it("Test circulating supply", async function () {
        await Celery.increaseBalanceAndStake(500);
        await expectCirculatingSupply(500);
    });

    it("Test supply using two staking accounts", async function () {
        await Celery.increaseBalanceAndStake(500);

        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await Celery.connect(this.user2).increaseBalanceAndStake(500);

        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await expectTotalStakingSupply(3000);

        await expectTotalPayoutSupply(0);

        await expectFullyDilutedSupply(3000);
    });

    it("Test supply using two payout accounts", async function () {

        await Celery.increaseBalanceAndStake(500);

        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await Celery.connect(this.user2).increaseBalanceAndStake(500);

        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await Celery.connect(this.user2).startPayout();

        await expectTotalStakingSupply(2000);

        await expectTotalPayoutSupply(1000);

        await expectFullyDilutedSupply(3000);

        await increaseBlockTime(SECONDS_IN_A_YEAR);

        await Celery.startPayout();

        await expectTotalStakingSupply(0);

        await expectTotalPayoutSupply(5000);

        await expectFullyDilutedSupply(5000);
        
    });
});

// *** Helper Functions *** //

function calculateStake(amount, stakedTime) {
    const percTime = stakedTime / SECONDS_IN_A_YEAR;
    return Math.ceil(amount * Math.pow(2, percTime));
}

// *** Expect Functions *** //

async function expectTotalPayoutSupply(amount) {
    await expect((await Celery.getTotalPayoutSupply()).toString()).to.equal(
        amount.toString()
    );
}

async function expectTotalStakingSupply(amount) {
    await expect((await Celery.getTotalStakingSupply()).toString()).to.equal(
        amount.toString()
    );
}

async function expectFullyDilutedSupply(amount) {
    await expect((await Celery.getFullyDilutedSupply()).toString()).to.equal(
        amount.toString()
    );
}

async function expectCirculatingSupply(amount) {
    await expect((await Celery.getCirculatingSupply()).toString()).to.equal(
        amount.toString()
    );
}

async function expectTokenBalance(address, amount) {
    await expect((await Celery.balanceOf(address)).toString()).to.equal(
        amount.toString()
    );
}

async function expectAccountAmount(address, amount) {
    await expect((await Celery.getAccountBalance(address)).toString()).to.equal(
        amount.toString()
    );
}

async function expectEndInterestTime(time) {
    await expect((await Celery.getEndInterestTime()).toString()).to.equal(
        time.toString()
    );
}

async function expectLastStakedBalance(address, amount) {
    await expect((await Celery.getLastStakingBalance(address)).toString()).to.equal(
        amount.toString()
    );
}

async function expectLastProcessedTime(address, time) {
    await expect((await Celery.getLastProcessedTime(address)).toString()).to.equal(
        time.toString()
    );
}

async function expectStatus(address, status) {
    await expect((await Celery.getStatus(address)).toString()).to.equal(
        status.toString()
    );
}

async function expectTotalSupply(amount) {
    await expect((await Celery.totalSupply()).toString()).to.equal(amount.toString());
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