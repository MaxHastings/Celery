async function main() {
    // We get the contract to deploy
    const Celery = await ethers.getContractFactory("Celery");
    const celery = await Celery.deploy("5000000000000000000000000000"); // Generate 5 billion Celery

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
