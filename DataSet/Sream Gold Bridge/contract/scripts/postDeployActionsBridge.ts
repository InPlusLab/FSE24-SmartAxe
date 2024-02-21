import * as dotenv from "dotenv";
import { Wallet } from "ethers";
import * as hre from "hardhat";
import { ethers } from "hardhat";
import config from "../configs/config.json";

dotenv.config();
/**
 * Here we need to set the FX Root Child tunnel address etc in the child contract and we can then start the test manually
 */
const fxERC20BridgeTunnel = "0x3b56d4c37FDA2c701787250b0C0277C6383Cf043";
const rootTunnel = "0x25a9AF323B3d3C49b3206FcaeD85C64Cab42Ba7e";
const rootToken = "0x1542Ac6e42940476c729680ff147E0CEDcFcFCf2";
const bridgeToken = "0x89F8f1734abe1AB8AdBCa64bAbc187f95b4BCcC8";

let feeAddr: Wallet, unbackedTreasury: Wallet, redeem: Wallet;

async function main() {
  let fxBridge, rootSGLDTOken;
  const accounts = await (ethers as any).getSigners();
  feeAddr = accounts[1];
  unbackedTreasury = accounts[2];
  redeem = accounts[3];
  const network = await hre.ethers.provider.getNetwork();

  if (network.chainId === 137) {
    // Polygon Mainnet
    fxBridge = config.mainnet.fxBridge.address;
    rootSGLDTOken = config.mainnet.fxERC20.address;
  } else if (network.chainId === 80001) {
    // Mumbai Testnet
    fxBridge = config.testnet.fxBridge.address;
    rootSGLDTOken = config.testnet.fxERC20.address;
  } else {
    rootSGLDTOken = process.env.FX_ERC20;
  }

  const SGLDBridgeFactory = await hre.ethers.getContractFactory("StreamGoldBridge");
  const cgt = await SGLDBridgeFactory.attach(bridgeToken);

  const BRIDGE = await hre.ethers.getContractFactory("FxERC20BridgeTunnel");
  const bridgeTunnel = BRIDGE.attach(fxERC20BridgeTunnel);
  const setRootTunnel = await bridgeTunnel.setFxRootTunnel(rootTunnel);
  await setRootTunnel.wait();

  const init = await cgt.initialize(
    feeAddr.address,
    accounts[0].address,
    fxERC20BridgeTunnel,
    rootSGLDTOken || "",
    "STREAM GOLD TOKEN",
    "SGLD",
    8
  );
  await init.wait();
  const unbacked = await cgt.setUnbackedAddress(unbackedTreasury.address);
  await unbacked.wait();
  const redeemTx = await cgt.setRedeemAddress(redeem.address);
  await redeemTx.wait();
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
  });
