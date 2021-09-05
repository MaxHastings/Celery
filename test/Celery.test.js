// test/Celery.test.js
// Load dependencies
const { expect } = require("chai");

// Start test Celery
describe("Celery", function () {
  before(async function () {
    this.Celery = await ethers.getContractFactory("Celery");
    this.owner = (await ethers.getSigners())[0];
  });

  beforeEach(async function () {
    this.Celery = await this.Celery.deploy(10000000);
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
});
