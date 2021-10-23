async function main() {
    // We get the contract to deploy
    const TokenSale = await ethers.getContractFactory("TokenSale");
    const tokenSale = await TokenSale.deploy("0x7E718bD0Cc18A5c6b252258504DC265c1FDF8067", "200000000000"); // Celery Contract Address, Price Per Celery In Wei

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
