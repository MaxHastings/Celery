// test/TokenSale.test.js
// Load dependencies
const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");
var Celery;
/* global describe,before,beforeEach,it,ethers */

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

        await TokenSale.startSale();

        // Test if tokens are in sale contract
        await expectAccountBalance(TokenSale.address, scaleTokenAmount(1000));

        // Have a buyer buy tokens
        await TokenSale.connect(this.buyer).buyTokens(1000, {
            value: 1000000,
        });

        // Test if account who bought tokens received them
        await expectAccountBalance(this.buyer.address, scaleTokenAmount(1000));

        // Test if contract balance decreased
        await expectAccountBalance(TokenSale.address, scaleTokenAmount(0));

        // Test if contract received Ethereum
        await expect(
            (await ethers.provider.getBalance(TokenSale.address)).toString()
        ).to.equal("1000000");

        //Test if ethereum was sent to owner after ending token sale.
        await expect(
            await TokenSale.endSale()
        ).to.changeEtherBalance(this.owner, 1000000);

    });

    it("Test too much value sent to Buy Tokens", async function () {
        // Transfer tokens to Token Sale contract
        await Celery.transfer(TokenSale.address, scaleTokenAmount(1000));

        await TokenSale.startSale();

        await expect(
            TokenSale.connect(this.buyer).buyTokens(1000, {
                value: 2000000,
            })
        ).to.be.revertedWith("Incorrect token value ratio");
    });

    it("Test too little value sent to Buy Tokens", async function () {
        // Transfer tokens to Token Sale contract
        await Celery.transfer(TokenSale.address, scaleTokenAmount(1000));

        await TokenSale.startSale();

        await expect(
            TokenSale.connect(this.buyer).buyTokens(1000, {
                value: 200,
            })
        ).to.be.revertedWith("Incorrect token value ratio");
    });

    it("Test buying more tokens than contract has", async function () {
        // Transfer tokens to Token Sale contract
        await Celery.transfer(TokenSale.address, scaleTokenAmount(1000));

        await TokenSale.startSale();

        await expect(
            TokenSale.connect(this.buyer).buyTokens(2000, {
                value: 2000000,
            })
        ).to.be.revertedWith("Out of tokens");
    });

    it("Test if not owner tries to Start Sale", async function () {
        await expect(TokenSale.connect(this.buyer).startSale()).to.be.revertedWith(
            "You must be the owner"
        );
    });

    it("Test if not owner tries to End Sale", async function () {
        await TokenSale.startSale();

        await expect(TokenSale.connect(this.buyer).endSale()).to.be.revertedWith(
            "You must be the owner"
        );
    });

    async function expectAccountBalance(address, amount) {
        expect((await Celery.balanceOf(address)).toString()).to.equal(
            amount.toString()
        );
    }
});
