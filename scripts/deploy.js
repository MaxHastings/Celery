async function main() {
    // We get the contract to deploy
    const Celery = await ethers.getContractFactory("Celery");
    const celery = await Celery.deploy("500000000000000000000"); // 5 billion

    console.log("Celery deployed!");
    console.log(`Contract Address: ${celery.address}`);
    console.log(`Contract From: ${celery.deployTransaction.from}`);
    console.log(`Contract TX Id: ${celery.deployTransaction.hash}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
