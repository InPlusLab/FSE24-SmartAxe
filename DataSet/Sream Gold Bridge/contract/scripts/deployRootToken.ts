// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { Contract } from "ethers";
import { config, ethers } from "hardhat";
import { Wallet } from "ethers";
import fs from "fs";
import { StreamGold } from "../../../typechain";
import * as hre from "hardhat";

const feeAddress = "0x3E924146306957bD453502e33B9a7B6AbA6e4D3a";
let backedTreasury: Wallet,
  testAddress: Wallet,
  unbackedTreasury: Wallet,
  redeem: Wallet;

async function main() {
  const accounts = await (ethers as any).getSigners();
  testAddress = accounts[0];
  backedTreasury = accounts[1];
  unbackedTreasury = accounts[2];
  redeem = accounts[3];
  console.log(" testAddress...", testAddress.address);

  // fs.unlinkSync(`${config.paths.artifacts}/contracts/contractAddress.ts`);

  const lockedGoldOracle = await ethers.getContractFactory("LockedGoldOracle");
  const _lockedGoldOracle = await lockedGoldOracle.deploy();
  console.log("Deploying lockedGoldOracle...", _lockedGoldOracle.address);
  await delay(50000);
  await _lockedGoldOracle.lockAmount(ethers.utils.parseUnits("8133525785", 8));
  const streamGoldFactory = await ethers.getContractFactory("Stream Gold");
  const streamGoldRoot = (await streamGoldFactory.deploy(
    unbackedTreasury.address,
    backedTreasury.address,
    feeAddress,
    redeem.address,
    _lockedGoldOracle.address
  )) as StreamGold;
  await delay(20000);

  await streamGoldRoot.addBackedTokens(ethers.utils.parseUnits("100000", 8));

  // set some gold in locked gold oracle
  // mint new tokens into backed treasury

  console.log("Deploying Stream Gold...", streamGoldRoot.address);

  return {
    streamGoldRoot: streamGoldRoot.address,
    unbackedTreasury: unbackedTreasury.address,
    backedTreasury: backedTreasury.address,
    feeAddress: feeAddress,
    redeem: redeem.address,
    lockedGoldOracle: _lockedGoldOracle.address,
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
    await verify(
      deployedData.streamGoldRoot,
      deployedData.unbackedTreasury,
      deployedData.backedTreasury,
      deployedData.feeAddress,
      deployedData.redeem,
      deployedData.lockedGoldOracle
    );
  })
  .catch((error) => {
    console.error(error);
  });

async function test() {
  await verify(
    "0x5d20692Be3324110E4D258D4ec0d129Dc39040E5",
    "0xd67afd601b53c60c4b359a54d95b4975f8a6988A",
    "0x3E95f7f86142d4f402e02A94f47201674D79b134",
    "0x3E924146306957bD453502e33B9a7B6AbA6e4D3a",
    "0x64B2436840074c177503D47871d17b38d424C7Fd",
    "0x5bC5CfB126CDD5E1Ffca561eFb396d4EA80885ae"
  );
}
// test();