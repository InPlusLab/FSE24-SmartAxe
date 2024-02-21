// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { Contract } from "ethers";
import { config, ethers } from "hardhat";
import { Wallet } from "ethers";
import fs from "fs";
import { StreamGoldBridge } from "../../../typechain";
import * as hre from "hardhat";

async function main() {
  const accounts = await (ethers as any).getSigners();
  console.log("Deployer Address - ", accounts[0].address);
  const streamGoldFactory = await ethers.getContractFactory("StreamGoldBridge");
  const streamGoldBridge = (await streamGoldFactory.deploy()) as StreamGoldBridge;
  await delay(20000);
  console.log("Deploying streamGold...", streamGoldBridge.address);

  return {
    streamGoldBridge: streamGoldBridge.address,
  };
}

async function verify(contractAddress: string, ...args: Array<any>) {
  console.log("verifying", contractAddress, ...args);
  await hre.run("verify:verify", {
    address: contractAddress,
    constructorArguments: [...args],
  });
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(async (deployedData) => {
    await delay(50000);
    await verify(deployedData.streamGoldBridge);
  })
  .catch((error) => {
    console.error(error);
  });

