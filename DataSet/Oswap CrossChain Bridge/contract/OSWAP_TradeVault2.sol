// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
// import "@openzeppelin/contracts/utils/Address.sol";
// import "./interfaces/IOSWAP_HybridRouter2.sol";
// import "./OSWAP_ConfigStoreTradeVault.sol";
// import "./OSWAP_TrollRegistry.sol";

// contract OSWAP_TradeVault2 is ReentrancyGuard/*, ERC721Holder*/ {
//     using SafeERC20 for IERC20;

//     function toUint256(int256 value) internal pure returns (uint256) {
//         require(value >= 0, "value < 0");
//         return uint256(value);
//     }
//     function toInt256(uint256 value) internal pure returns (int256) {
//         require(value <= uint256(type(int256).max), "value > int256.max");
//         return int256(value);
//     }
//     function _transferFrom(IERC20 asset, address from, uint amount) internal returns (uint256 balance) {
//         balance = asset.balanceOf(address(this));
//         asset.safeTransferFrom(from, address(this), amount);
//         balance = asset.balanceOf(address(this)) - balance;
//     }

//     modifier onlyEndUser() {
//         require((tx.origin == msg.sender && !Address.isContract(msg.sender)), "Not from end user");
//         _;
//     }

//     // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
//     bytes32 public constant EIP712_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
//     // keccak256("OpenSwap")
//     bytes32 public constant NAME_HASH = 0xccf0ed8d136d82190c405c1be2cf07fff31d482a66996af4f69b3259174a23ba;
//     // keccak256(bytes('1'))
//     bytes32 public constant VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;
//     // keccak256("Order(uint256 nonce,address srcToken,address outToken,uint256 price,uint256 tradeLotSize,uint256 maxCount,uint256 startDate,uint256 endDate)");
//     bytes32 public constant ORDER_TYPEHASH = 0x6905fba9e619c87ed0972f27005d4489fe956f8375788616eab2d159c11763e9;
//     // keccak256(abi.encode(EIP712_TYPEHASH, NAME_HASH, VERSION_HASH, chainId, address(this)));
//     bytes32 immutable DOMAIN_SEPARATOR;


//     event TopupFee(address indexed owner, uint256 amount, uint256 balance);
//     event WithdrawFee(address indexed provider, uint256 amount, uint256 balance);
//     event Swap(address indexed provider, address indexed troll, bytes32 indexed id, uint256 inAmount, uint256 outAmount);
//     event VoidOrder(address indexed owner, address indexed troll, uint256 indexed nonce);
//     event UpdateConfigStore(OSWAP_ConfigStoreTradeVault newConfigStore);


//     struct Order {
//         uint256 nonce;
//         IERC20 srcToken;
//         IERC20 outToken;
//         uint256 price; // min price
//         uint256 tradeLotSize; // max amount per trade 
//         uint256 maxCount;
//         uint256 startDate;
//         uint256 endDate;
//     }

//     mapping(bytes32 => uint256) public counts;
//     mapping(address => uint256) public voidedNonce;
//     mapping(address => uint256) public lpFeeBalances; // lpFeeBalances[owner] = balance

//     IERC20 public immutable govToken;
//     uint256 public totalLpFeeBalance;
//     // uint256 public protocolFeeCollected;

//     OSWAP_ConfigStoreTradeVault public configStore;

//     constructor(IERC20 _govToken, OSWAP_ConfigStoreTradeVault _configStore) {
//         govToken = _govToken;
//         configStore = _configStore;

//         uint chainId;
//         assembly {
//             chainId := chainid()
//         }
//         DOMAIN_SEPARATOR = keccak256(abi.encode(EIP712_TYPEHASH, NAME_HASH, VERSION_HASH, chainId, address(this)));
//     }
//     function updateConfigStore() external {
//         configStore = configStore.newConfigStore();
//         emit UpdateConfigStore(configStore);
//     }

//     function topupFee(
//         uint256 fee
//     ) external nonReentrant {
//         govToken.safeTransferFrom(msg.sender, address(this), fee);
//         lpFeeBalances[msg.sender] += fee;
//         totalLpFeeBalance += fee;
//         emit TopupFee(msg.sender, fee, lpFeeBalances[msg.sender]);
//     }
//     function withdrawFee(
//         uint256 fee
//     ) external nonReentrant {
//         require(fee <= lpFeeBalances[msg.sender], "Insufficient fee balance");
//         lpFeeBalances[msg.sender] -= fee;
//         totalLpFeeBalance -= fee;
//         emit WithdrawFee(msg.sender, fee, lpFeeBalances[msg.sender]);
//     }

//     function recover(bytes32 paramHash, bytes memory signature) public pure returns (address) {
//         bytes32 r;
//         bytes32 s;
//         uint8 v;
//         if (signature.length != 65) {
//             return (address(0));
//         }
//         assembly {
//             r := mload(add(signature, 0x20))
//             s := mload(add(signature, 0x40))
//             v := byte(0, mload(add(signature, 0x60)))
//         }
//         if (v < 27) {
//             v += 27;
//         }
//         if (v != 27 && v != 28) {
//             return (address(0));
//         } else {
//             // paramHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", paramHash));
//             return ecrecover(paramHash, v, r, s);
//         }
//     }
//     function hashOrder(Order calldata order) public view returns(bytes32) {
//         return keccak256(
//             abi.encodePacked(
//                 '\x19\x01',
//                 DOMAIN_SEPARATOR,
//                 keccak256(abi.encode(
//                     ORDER_TYPEHASH, 
//                     order.nonce,
//                     order.srcToken,
//                     order.outToken,
//                     order.price,
//                     order.tradeLotSize,
//                     order.maxCount,
//                     order.startDate,
//                     order.endDate
//                 ))
//             )
//         );
//     }
//     function hashVoidOrder(uint256 nonce) public view returns(bytes32 hash) {
//         uint256 chainId;
//         assembly {
//             chainId := chainid()
//         }
//         hash = keccak256(abi.encodePacked(
//             chainId,
//             address(this),
//             nonce
//         ));
//     }

//     function voidOrder(
//         bytes calldata signatures, 
//         uint256 nonceToVoid
//     ) external onlyEndUser nonReentrant {
//         bytes32 hash = hashVoidOrder(nonceToVoid);
//         address owner = recover(hash, signatures);
//         require(owner != address(0), "Invalid signer");
//         require(voidedNonce[owner] < nonceToVoid, "Invlid nonce");
//         voidedNonce[owner] = nonceToVoid;
//         emit VoidOrder(owner, msg.sender, nonceToVoid);
//     }

//     function swapExactTokensForTokens(
//         bytes calldata signatures,
//         uint256 inAmount,
//         address[] calldata pair,
//         uint256 deadline, 
//         Order calldata order
//     ) external onlyEndUser nonReentrant /*returns (uint256[] memory amounts) */{
//         require(address(order.srcToken) != address(order.outToken), "Same tokens");

//         bytes32 id = hashOrder(order);
//         address owner = recover(id, signatures);
//         require(owner != address(0), "Invalid signer");

//         require(voidedNonce[owner] < order.nonce, "Expired nonce");
//         require(counts[id] < order.maxCount, "Max count reached");
//         require(inAmount <= order.tradeLotSize, "excceeded lot size");
//         require(order.startDate <= block.timestamp && block.timestamp <= order.endDate, "Order not started / expired");
//         order.srcToken.safeTransferFrom(owner, address(this), inAmount);
//         // require(inAmount <= lpBalances[owner][order.srcToken], "Insufficient balance");

//         address router; 
//         {
//         uint256 fee;
//         (router, fee) = configStore.getTradeParam();
//         if (counts[id] == 0) {
//             require(lpFeeBalances[owner] >= fee, "not enough fee");
//             lpFeeBalances[owner] -= fee;
//             totalLpFeeBalance -= fee;
//             // protocolFeeCollected += fee;
//         }
//         }
//         counts[id]++;

//         uint256 outTokenBalance = order.outToken.balanceOf(address(owner));
//         order.srcToken.approve(router, inAmount);
//         {
//         uint minOutAmount = inAmount * order.price / 10e18;
//         IOSWAP_HybridRouter2(router).swapExactTokensForTokens(inAmount, minOutAmount, pair, address(order.srcToken), owner, deadline, "0x");
//         outTokenBalance = order.outToken.balanceOf(address(owner)) - outTokenBalance;
//         require(outTokenBalance >= minOutAmount, "Insufficient output");
//         }

//         emit Swap(owner, msg.sender, id, inAmount, outTokenBalance);
//     }
//     function redeemFund(IERC20 token) external {
//         if (token == govToken) {
//             uint256 amount = govToken.balanceOf(address(this)) - totalLpFeeBalance;
//             // protocolFeeCollected = 0;
//             govToken.safeTransfer(configStore.feeTo(), amount);
//         } else {
//             uint256 amount = token.balanceOf(address(this));
//             token.safeTransfer(configStore.feeTo(), amount);
//         }
//     }
// }
