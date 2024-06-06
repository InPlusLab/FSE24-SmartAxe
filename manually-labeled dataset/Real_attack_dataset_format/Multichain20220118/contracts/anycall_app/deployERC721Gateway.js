const fs = require('fs');

var Web3 = require('web3');
var fantomTestnet = new Web3(new Web3.providers.HttpProvider('https://rpc.testnet.fantom.network'));
var rinkeby = new Web3(new Web3.providers.HttpProvider('https://rinkeby.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161'));

var privatekey = ""

let anycall_ftm_addr = '0xD7c295E399CA928A3a14b01D760E794f1AdF8990';
let executor_ftm_addr = '0xe3aee52608db94f2691a7f9aba30235b14b7bb70';
let anycall_rkb_addr = '0x273a4fFcEb31B8473D51051Ad2a2EdbB7Ac8Ce02';
let executor_rkb_addr = '0x332c97a68156351bd4e7bc4c96df79d199514f14';

async function send(web3, transaction, gas) {
    const options = {
        to   : transaction._parent._address,
        data : transaction.encodeABI(),
        gas  : gas
    };
    const signedTransaction  = await web3.eth.accounts.signTransaction(options, privatekey);
    //console.log("signedTransaction === " + JSON.stringify(signedTransaction));
    return web3.eth.sendSignedTransaction(signedTransaction.rawTransaction);
}

async function deploy(web3, contractName, contractArgs, gas) {
    var abi = fs.readFileSync("./abi/" + contractName + ".json");
    abi = ("" + abi).trim();
    var bin = fs.readFileSync("./bin/" + contractName + ".txt");
    bin = ("" + bin).trim();
    const contract = new web3.eth.Contract(JSON.parse(abi));
    const options = {data: "0x" + bin, arguments: contractArgs};
    const transaction = contract.deploy(options);
    const handle = await send(web3, transaction, gas);
    console.log(handle.transactionHash);
    const args = transaction.encodeABI().slice(options.data.length);
    return new web3.eth.Contract(JSON.parse(abi), handle.contractAddress);
}

var token_ftm;
var token_rkb;
var gateway_ftm;
var gateway_rkb;
var flag = 0;

async function deployFTMToken() {
    console.log("deploying fantom testnet erc721 token");
    token_ftm = await deploy(fantomTestnet, "SimpleMintBurnERC721", ["Telebubbies Token", "TTT"], 1800000);
    console.log("deployed fantom token" + "===" + token_ftm.options.address);
}

async function deployRinkebyToken() {
    console.log("deploying rinkeby testnet erc721 token");
    token_rkb = await deploy(rinkeby, "SimpleMintBurnERC721", ["Telebubbies Token", "TTT"], 1800000);
    console.log("deployed rinkeby token" + "===" + token_rkb.options.address);
}

async function deployFTMGateway() {
    console.log("deploying fantom testnet gateway" + " === args === " + anycall_ftm_addr + " " + flag + " " + token_ftm.options.address);
    gateway_ftm = await deploy(fantomTestnet, "ERC721Gateway_MintBurn", [anycall_ftm_addr, flag, token_ftm.options.address], 1300000);
    console.log("deployed fantom gateway" + "===" + gateway_ftm.options.address);
}

async function deployRKBGateway() {
    console.log("deploying rinkeby testnet gateway" + " === args === " + anycall_rkb_addr + " " + flag + " " + token_rkb.options.address);
    gateway_rkb = await deploy(rinkeby, "ERC721Gateway_MintBurn", [anycall_rkb_addr, flag, token_rkb.options.address], 1300000);
    console.log("deployed rinkeby gateway" + "===" + gateway_rkb.options.address);
}

async function setFTMGateway() {
    console.log("setting fantom testnet gateway" + " === args === " + gateway_rkb.options.address);
    gateway_ftm.methods.setPeers([4], [gateway_rkb.options.address]).send().then(console.log);
}

async function setRKBGateway() {
    console.log("setting rinkeby testnet gateway" + " === args === " + gateway_ftm.options.address);
    gateway_rkb.methods.setPeers([4002], [gateway_ftm.options.address]).send().then(console.log);
}

async function deposit() {
    var abi = fs.readFileSync("./abi/anycall.json");
    abi = ("" + abi).trim();

    let anycall_ftm = new fantomTestnet.eth.Contract(JSON.parse(abi), anycall_ftm_addr);
    anycall_ftm.methods.deposit([gateway_rkb.options.address]).send({value: 0.1}).then(console.log);
                            
    let anycall_rkb = new rinkeby.eth.Contract(JSON.parse(abi), anycall_rkb_addr);
    anycall_rkb.methods.deposit([gateway_ftm.options.address]).send({value: 0.1}).then(console.log);
}

async function main() {
    await deployFTMToken();
    await deployRinkebyToken();
    await deployFTMGateway();
    await deployRKBGateway();
    await setFTMGateway();
    await setRKBGateway();
    await deposit();
}

main();