import { ethers } from "hardhat";
import { CacheGold } from "../../../typechain";
import * as hre from "hardhat";

const rootTunnel = "0x25a9AF323B3d3C49b3206FcaeD85C64Cab42Ba7e";
const rootToken = "0x1542Ac6e42940476c729680ff147E0CEDcFcFCf2";
const childToken = "0x89F8f1734abe1AB8AdBCa64bAbc187f95b4BCcC8";

async function main() {
  const accounts = await (ethers as any).getSigners();
  console.log("The user with the moolah = ", accounts[4].address);
  const streamGoldFactory = await ethers.getContractFactory("Stream Gold");
  const streamGoldRoot = streamGoldFactory.attach(rootToken) as StreamGold;
  // You will want to use your own tunnel addresses here instead!
  const TunnelFactory = await hre.ethers.getContractFactory(
    "FxStreamRootTunnel"
  );
  const streamTunnel = await TunnelFactory.attach(rootTunnel);

  const setExempt = await streamGoldRoot.setFeeExempt(rootTunnel);
  await setExempt.wait();

  const approve = await streamGoldRoot
    .connect(accounts[4])
    .approve(rootTunnel, ethers.utils.parseUnits("10", 8));
  await approve.wait();
  console.log("Approved SGLD Tokens");

  const deposit = await streamTunnel
    .connect(accounts[4])
    .deposit(
      rootToken,
      childToken,
      accounts[4].address,
      ethers.utils.parseUnits("100", 8),
      ethers.utils.formatBytes32String("")
    );

  await deposit.wait();

  console.log("deposited streamGold...");
}
main();
