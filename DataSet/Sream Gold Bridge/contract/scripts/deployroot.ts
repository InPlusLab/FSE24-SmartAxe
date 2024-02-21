import * as dotenv from "dotenv";
import * as hre from "hardhat";
import config from "../configs/config.json";

// Use your own deployed bridge tunnel addresses here instead!
const fxERC20BridgeTunnel = "0x3b56d4c37FDA2c701787250b0C0277C6383Cf043";

async function main() {
  let fxRoot, checkpointManager, fxERC20;

  const network = await hre.ethers.provider.getNetwork();

  if (network.chainId === 1) {
    // Ethereum Mainnet
    fxRoot = config.mainnet.fxRoot.address;
    checkpointManager = config.mainnet.checkpointManager.address;
  } else if (network.chainId === 5) {
    // Goerli Testnet
    fxRoot = config.testnet.fxRoot.address;
    checkpointManager = config.testnet.checkpointManager.address;
  } else {
    fxRoot = process.env.FX_ROOT;
    checkpointManager = process.env.CHECKPOINT_MANAGER;
  }

  // You will want to use your own tunnel addresses here instead!
  const ERC20 = await hre.ethers.getContractFactory("FxStreamRootTunnel");
  const erc20 = await ERC20.deploy(checkpointManager || "", fxRoot || "");
  console.log(erc20.deployTransaction);
  await erc20.deployTransaction.wait();
  console.log("ERC20RootTunnel deployed to:", erc20.address);
  console.log(
    "npx hardhat verify --network goerli",
    erc20.address,
    checkpointManager,
    fxRoot
  );

  const setERC20Bridge = await erc20.setFxBridgeTunnel(fxERC20BridgeTunnel);
  // console.log(setERC20Bridge);
  await setERC20Bridge.wait();
  // console.log("ERC20BridgeTunnel set");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
