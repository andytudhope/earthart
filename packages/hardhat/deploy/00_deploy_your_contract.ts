import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Deploys a contract named "Earth" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployEarth: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network goerli`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("Earth", {
    from: deployer,
    // Contract constructor arguments
    args: [
      "0x5f3371793285920351344a1EaaAA48d45e600652", // steward
      ["0x5f3371793285920351344a1EaaAA48d45e600652"], // addresses to split the sale funds between
      [100], // split applied to above addresses
      "Aether, Earth, & Art", // name
      "EARTH", // symbol
      [
        "ipfs://bafybeide2u3kthepdm3t3xpcirarkh4isaurkhzghldsl55m65y5qczcmi/",
        "https://metadata.mintplex.xyz/wrYvhRZx9EtKojZZLSO1/contract-metadata",
      ], // base uri, contract uri
      [5, 5], // maxMintsPerTx, collectionSize
      [hre.ethers.utils.parseEther("0.05"), 100], // mintPrice, maxWalletMints
    ],
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  });
};

export default deployEarth;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags YourContract
deployEarth.tags = ["Earth"];
