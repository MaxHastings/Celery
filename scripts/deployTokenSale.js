async function main() {
    // We get the contract to deploy
    const TokenSale = await ethers.getContractFactory("TokenSale");
    const tokenSale = await TokenSale.deploy("0x7642Df81b5BEAeEb331cc5A104bd13Ba68c34B91", "200000000000"); // Celery Contract Address, Price Per Celery In Wei

    console.log("TokenSale deployed!");
    console.log(`Contract Address: ${tokenSale.address}`);
    console.log(`Contract From: ${tokenSale.deployTransaction.from}`);
    console.log(`Contract TX Id: ${tokenSale.deployTransaction.hash}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
