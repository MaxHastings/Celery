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
            from: "0x196BC2aa82988aC70EBdaa311c4768b037B7aA54", //Address contract is coming from (should have a balance if using accounts = remote)
            gas: "auto",
            gasPrice: 0x10000000000,
            gasMultiplier: 1,
            accounts: "remote" // Rely on connected RPC to do the signing of TX
        },
        testnet: {
            url: "http://35.220.203.194:8545",
            chainId: 0x2711,
            from: "0x423e901457cad8b0A824D52DFcFdc47e93844B60", //Address contract is coming from (this accounts private key should be in accounts array below)
            gas: "auto",
            gasPrice: 1000000000,
            gasMultiplier: 1,
            accounts: [] // Private key to sign TX from (add one private key string to array) (DO NOT COMMIT)
        },
        mainnet: {
            url: "https://smartbch.fountainhead.cash/mainnet",
            chainId: 10000,
            from: "", //Address contract is coming from (this accounts private key should be in accounts array below)
            gas: "auto",
            gasPrice: 1000000000,
            gasMultiplier: 1,
            accounts: [] // Private key to sign TX from (add one private key string to array) (DO NOT COMMIT)
        }
    }
};
