import * as dotenv from "dotenv";
import * as hre from "hardhat";
import config from "../configs/config.json";

dotenv.config();
async function main() {
  let fxChild;

  const network = await hre.ethers.provider.getNetwork();

  if (network.chainId === 137) {
    // Polygon Mainnet
    fxChild = config.mainnet.fxChild.address;
  } else if (network.chainId === 80001) {
    // Mumbai Testnet
    fxChild = config.testnet.fxChild.address;
  } else {
    fxChild = process.env.FX_CHILD;
  }

  const ERC20 = await hre.ethers.getContractFactory("FxERC20ChildTunnel");
  const erc20 = await ERC20.deploy(fxChild || "");
  await erc20.deployTransaction.wait();
  console.log("ERC20ChildTunnel deployed to:", erc20.address);
  console.log("npx hardhat verify --network mumbai", erc20.address, fxChild);
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
  });
