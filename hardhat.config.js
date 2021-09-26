require("@nomiclabs/hardhat-waffle");
require("solidity-coverage");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.4",
    settings: {
        optimizer: {
            enabled: true,
            runs: 200
        }
    },
    networks: {
        localtestnet: {
            url: "http://192.168.3.110:8545",
            chainId: 0x2711,
            from: "0x196BC2aa82988aC70EBdaa311c4768b037B7aA54",
            gas: "auto",
            gasPrice: 0x10000000000,
            gasMultiplier: 1,
            accounts: "remote"
        }
    }
};
