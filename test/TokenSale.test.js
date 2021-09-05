// test/TokenSale.test.js
// Load dependencies
const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
const hre = require("hardhat");

var Celery;

var TokenSale;

const initialSupply = scaleTokenAmount(100000000);

function scaleTokenAmount(amount) {
  const base10 = BigNumber.from(10);
  return BigNumber.from(amount).mul(base10.pow(18));
}
// Start test Token Sale
describe("TokenSale", function () {
  before(async function () {
    this.CeleryFactory = await ethers.getContractFactory("Celery");
    this.TokenSaleFactory = await ethers.getContractFactory("TokenSale");
    this.signers = await ethers.getSigners();
    this.owner = this.signers[0];
    this.buyer = this.signers[1];
  });

  beforeEach(async function () {
    Celery = await this.CeleryFactory.deploy(initialSupply);
    await Celery.deployed();
    TokenSale = await this.TokenSaleFactory.deploy(Celery.address, 1000);
    await TokenSale.deployed();
  });

  // Test case
  it("Test Buy Tokens", async function () {
    // Transfer tokens to Token Sale contract
    await Celery.transfer(TokenSale.address, scaleTokenAmount(1000));

    // Test if tokens are in sale contract
    await expectAccountBalance(TokenSale.address, scaleTokenAmount(1000));

    // Have a buyer buy tokens
    await TokenSale.connect(this.buyer).BuyTokens(1000, {
      value: 1000000,
    });

    // Test if account who bought tokens received them
    await expectAccountBalance(this.buyer.address, scaleTokenAmount(1000));

    // Test if contract balance decreased
    await expectAccountBalance(TokenSale.address, scaleTokenAmount(0));
  });

  async function expectAccountBalance(address, amount) {
    expect((await Celery.balanceOf(address)).toString()).to.equal(
      amount.toString()
    );
  }
});
