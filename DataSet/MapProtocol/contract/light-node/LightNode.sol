// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./lib/RLPReader.sol";
import "./lib/RLPEncode.sol";

// import "hardhat/console.sol";

contract LightNode is UUPSUpgradeable, Initializable {
    using RLPReader for bytes;
    using RLPReader for uint256;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;

    struct blockHeader {
        bytes parentHash;
        address coinbase;
        bytes root;
        bytes txHash;
        bytes receipHash;
        bytes bloom;
        uint256 number;
        uint256 gasLimit;
        uint256 gasUsed;
        uint256 time;
        bytes extraData;
        bytes mixDigest;
        bytes nonce;
        uint256 baseFee;
    }

    struct istanbulAggregatedSeal {
        uint256 round;
        bytes signature;
        uint256 bitmap;
    }

    struct istanbulExtra {
        address[] validators;
        bytes seal;
        istanbulAggregatedSeal aggregatedSeal;
        istanbulAggregatedSeal parentAggregatedSeal;
        uint256 removeList;
        bytes[] addedPubKey;
    }

    struct txParams {
        address From;
        address To;
        uint256 Value;
    }

    struct txProve {
        bytes header;
        txParams Tx;
        bytes receipt;
        bytes32[] prove;
    }

    struct Log {
        address addr;
        bytes[] topics;
        bytes data;
    }

    // LogSwapOut(bytes32,address,address,address,uint256,uint256,uint256)
    bytes32 constant EventHash =
        0xcfdd266a10c21b3f2a2da4a807706d3f3825d37ca51d341eef4dce804212a8a3;

    uint256 constant EPOCHCOUNT = 3;
    uint256 private epochIdx;
    uint256[EPOCHCOUNT] private epochs;
    // epoch => bls keys
    mapping(uint256 => bytes[]) private blsKey;

    uint256 epochLength;
    uint256 keyNum;

    event validitorsSet(uint256 epoch);

    /** initialize  **********************************************************/
    function initialize(bytes memory firstBlock, uint256 epoch)
        external
        initializer
    {
        _changeAdmin(msg.sender);
        epochLength = 20;
        _initFirstBlock(firstBlock, epoch);
    }

    constructor() initializer {}

    /** view function *********************************************************/
    function currentEpoch() public view returns (uint256) {
        return epochs[epochIdx];
    }

    function currentValidators() public view returns (bytes[] memory) {
        return blsKey[currentEpoch()];
    }

    /** external function *********************************************************/
    function save(bytes memory rlpHeader) external {
        (
            bool ret,
            uint256 removeList,
            bytes[] memory addedPubKey
        ) = _verifyHeader(rlpHeader);
        require(ret, "verifyHeader failed");
        _changeValidators(removeList, addedPubKey);
    }

    function txVerify(
        address router,
        address,
        uint256 srcChain,
        uint256 dstChain,
        bytes calldata rlpTxProve
    ) external pure returns (bool success, string memory message) {
        txProve memory txp = _decodeTxProve(rlpTxProve);
        blockHeader memory bh = _decodeHeader(txp.header);
        Log[] memory logs = _decodeTxReceipt(txp.receipt);

        (Log memory lg, bool found) = _queryLog(router, logs);
        if (!found) {
            return (false, "LightNode: event log not found");
        }

        (success, message) = _verifyTxParams(srcChain, dstChain, txp.Tx, lg);
        if (!success) {
            return (success, message);
        }

        bytes32 leaf = keccak256(txp.receipt);
        bytes32 root = bytes32(bh.receipHash);
        success = MerkleProof.verify(txp.prove, root, leaf);
        if (!success) {
            message = "receipt mismatch";
        }
    }

    /** sstore functions *******************************************************/

    function _initFirstBlock(bytes memory firstBlock, uint256 epoch) private {
        blockHeader memory bh = _decodeHeader(firstBlock);
        istanbulExtra memory ist = _decodeExtraData(bh.extraData);

        keyNum = ist.addedPubKey.length;
        // nowNumber = bh.number;
        bytes[] memory keys = new bytes[](keyNum);
        for (uint256 i = 0; i < keyNum; i++) {
            keys[i] = ist.addedPubKey[i];
        }
        _setValidators(keys, epoch);
    }

    function _setValidators(bytes[] memory keys, uint256 epoch) private {
        uint256 nextIdx = epochIdx + 1;
        if (nextIdx == EPOCHCOUNT) {
            nextIdx = 0;
        }

        if (epochs[nextIdx] != 0) {
            // delete previous data
            delete blsKey[epochs[nextIdx]];
        }

        epochs[nextIdx] = epoch;
        blsKey[epoch] = keys;
        epochIdx = nextIdx;
        emit validitorsSet(epoch);
    }

    function _changeValidators(uint256 removedVal, bytes[] memory addVal)
        private
    {
        (uint256[] memory list, uint8 oldVal) = _readRemoveList(removedVal);
        bytes[] memory newKeys = new bytes[](oldVal + addVal.length);
        bytes[] memory currentKeys = currentValidators();

        uint256 j = 0;
        //if value is 1, the related address will be not validaor at nest epoch.
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == 0) {
                newKeys[j] = currentKeys[i];
                j = j + 1;
            }
        }
        for (uint256 i = 0; i < addVal.length; i++) {
            newKeys[j] = addVal[i];
            j = j + 1;
        }

        // nowEpoch = nowEpoch + 1;
        //require(j<101,"the number of validators is more than 100")

        uint256 newEpoch = currentEpoch() + 1;
        _setValidators(newKeys, newEpoch);
    }

    /** private functions about header manipulation  ************************************/

    function _decodeTxProve(bytes memory rlpBytes)
        private
        pure
        returns (txProve memory txp)
    {
        RLPReader.RLPItem[] memory ls = rlpBytes.toRlpItem().toList();
        RLPReader.RLPItem[] memory item1ls = ls[1].toList();
        RLPReader.RLPItem[] memory item3ls = ls[3].toList();

        uint256 num = item3ls.length;
        bytes32[] memory receipProve = new bytes32[](num);
        for (uint256 i = 0; i < num; i++) {
            receipProve[i] = bytes32(item3ls[i].toBytes());
        }

        txp = txProve({
            header: ls[0].toBytes(),
            Tx: txParams({
                From: item1ls[0].toAddress(),
                To: item1ls[1].toAddress(),
                Value: item1ls[2].toUint()
            }),
            receipt: ls[2].toBytes(),
            prove: receipProve
        });
    }

    function _decodeTxReceipt(bytes memory rlpBytes)
        private
        pure
        returns (Log[] memory logs)
    {
        RLPReader.RLPItem[] memory ls = rlpBytes.toRlpItem().toList();
        RLPReader.RLPItem[] memory i5ls = ls[5].toList(); //logs

        uint256 num = i5ls.length;
        logs = new Log[](num);
        for (uint256 i = 0; i < num; i++) {
            RLPReader.RLPItem[] memory l = i5ls[i].toList();
            logs[i].addr = l[0].toAddress();

            RLPReader.RLPItem[] memory topicls = l[1].toList();
            uint256 n1 = topicls.length;
            logs[i].topics = new bytes[](n1);
            for (uint256 j = 0; j < n1; j++) {
                logs[i].topics[j] = topicls[j].toBytes();
            }

            logs[i].data = l[2].toBytes();
        }
    }

    function _queryLog(address coinAddr, Log[] memory logs)
        private
        pure
        returns (Log memory lg, bool found)
    {
        found = false;
        uint256 num = logs.length;
        for (uint256 i = 0; i < num; i++) {
            if (logs[i].addr == coinAddr) {
                if (bytes32(logs[i].topics[0]) == EventHash) {
                    return (logs[i], true);
                }
            }
        }
    }

    function _verifyTxParams(
        uint256 srcChain,
        uint256 dstChain,
        txParams memory txparams,
        Log memory log
    ) private pure returns (bool suc, string memory message) {
        if (log.topics.length < 4) {
            return (false, "Topics`s length cannot be less than 4");
        }

        if (txparams.From != address(bytes20(log.topics[2]))) {
            return (false, "invalid from");
        }

        if (txparams.To != address(bytes20(log.topics[3]))) {
            return (false, "invalid to");
        }

        if (log.data.length < 128) {
            return (false, "log.Data length cannot be less than 128");
        }

        if (txparams.Value != uint256(_bytesSlice32(log.data, 32))) {
            return (false, "invalid value");
        }

        if (srcChain != uint256(_bytesSlice32(log.data, 64))) {
            return (false, "invalid srcChain");
        }

        if (dstChain != uint256(_bytesSlice32(log.data, 96))) {
            return (false, "invalid srcChain");
        }
        suc = true;
    }

    function _bytesSlice32(bytes memory data, uint256 offset)
        private
        pure
        returns (bytes32 slice)
    {
        bytes memory tmp = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            tmp[i] = data[offset + 1];
        }
        slice = bytes32(tmp);
    }

    function _decodeHeader(bytes memory rlpBytes)
        private
        pure
        returns (blockHeader memory bh)
    {
        RLPReader.RLPItem[] memory ls = rlpBytes.toRlpItem().toList();

        // part1
        // RLPReader.RLPItem memory item0 = ls[0]; //parentBlockHash
        // RLPReader.RLPItem memory item1 = ls[1]; //coinbase
        // RLPReader.RLPItem memory item2 = ls[2]; //root
        // RLPReader.RLPItem memory item3 = ls[3]; //txHash
        // RLPReader.RLPItem memory item4 = ls[4]; //receipHash
        // RLPReader.RLPItem memory item6 = ls[6]; //number
        // RLPReader.RLPItem memory item10 = ls[10]; //extra
        // part2
        // RLPReader.RLPItem memory item5 = ls[5]; //bloom
        // RLPReader.RLPItem memory item7 = ls[7]; //gasLimit
        // RLPReader.RLPItem memory item8 = ls[8]; //gasUsed
        // RLPReader.RLPItem memory item9 = ls[9]; //time
        // RLPReader.RLPItem memory item11 = ls[11]; //mixDigest
        // RLPReader.RLPItem memory item12 = ls[12]; //nonce
        // RLPReader.RLPItem memory item13 = ls[13]; //baseFee

        bh = blockHeader({
            parentHash: ls[0].toBytes(),
            coinbase: ls[1].toAddress(),
            root: ls[2].toBytes(),
            txHash: ls[3].toBytes(),
            receipHash: ls[4].toBytes(),
            number: ls[6].toUint(),
            extraData: ls[10].toBytes(),
            bloom: ls[5].toBytes(),
            gasLimit: ls[7].toUint(),
            gasUsed: ls[8].toUint(),
            time: ls[9].toUint(),
            mixDigest: ls[11].toBytes(),
            nonce: ls[12].toBytes(),
            baseFee: ls[13].toUint()
        });
    }

    function _encodeHeader(blockHeader memory bh)
        private
        pure
        returns (bytes memory output)
    {
        bytes[] memory list = new bytes[](14);
        list[0] = RLPEncode.encodeBytes(bh.parentHash); //
        list[1] = RLPEncode.encodeAddress(bh.coinbase); //
        list[2] = RLPEncode.encodeBytes(bh.root); //
        list[3] = RLPEncode.encodeBytes(bh.txHash); //
        list[4] = RLPEncode.encodeBytes(bh.receipHash); //
        list[5] = RLPEncode.encodeBytes(bh.bloom); //
        list[6] = RLPEncode.encodeUint(bh.number); //
        list[7] = RLPEncode.encodeUint(bh.gasLimit); //;
        list[8] = RLPEncode.encodeUint(bh.gasUsed); //
        list[9] = RLPEncode.encodeUint(bh.time); //
        list[10] = RLPEncode.encodeBytes(bh.extraData); //
        list[11] = RLPEncode.encodeBytes(bh.mixDigest); //
        list[12] = RLPEncode.encodeBytes(bh.nonce); //
        list[13] = RLPEncode.encodeUint(bh.baseFee); //
        output = RLPEncode.encodeList(list);
    }

    function _decodeExtraData(bytes memory extraData)
        private
        pure
        returns (istanbulExtra memory ist)
    {
        bytes memory decodeBytes = _splitExtra(extraData);
        RLPReader.RLPItem[] memory ls = decodeBytes.toRlpItem().toList();
        RLPReader.RLPItem memory item0 = ls[0];
        RLPReader.RLPItem memory item1 = ls[1];
        RLPReader.RLPItem memory item2 = ls[2];
        RLPReader.RLPItem memory item3 = ls[3];
        RLPReader.RLPItem memory item4 = ls[4];
        RLPReader.RLPItem memory item5 = ls[5];

        ist = istanbulExtra({
            removeList: item2.toUint(),
            seal: item3.toBytes(),
            aggregatedSeal: istanbulAggregatedSeal({
                round: item4.toList()[2].toUint(),
                signature: item4.toList()[1].toBytes(),
                bitmap: item4.toList()[0].toUint()
            }),
            parentAggregatedSeal: istanbulAggregatedSeal({
                round: item5.toList()[2].toUint(),
                signature: item5.toList()[1].toBytes(),
                bitmap: item5.toList()[0].toUint()
            }),
            validators: new address[](0),
            addedPubKey: new bytes[](0)
        });
        if (item0.len > 20) {
            uint256 num = item0.len / 20;
            ist.validators = new address[](num);
            ist.addedPubKey = new bytes[](num);
            for (uint256 i = 0; i < num; i++) {
                ist.validators[i] = item0.toList()[i].toAddress();
                ist.addedPubKey[i] = item1.toList()[i].toBytes();
            }
        }
    }

    function _splitExtra(bytes memory extra)
        private
        pure
        returns (bytes memory newExtra)
    {
        //extraData rlpcode is storaged from No.32 byte to latest byte.
        //So, the extraData need to reduce 32 bytes at the beginning.
        newExtra = new bytes(extra.length - 32);
        // extraDataPre = new bytes(32);
        uint256 n = 0;
        for (uint256 i = 32; i < extra.length; i++) {
            newExtra[n] = extra[i];
            n = n + 1;
        }
        // uint m = 0;
        // for(uint i=0;i<32;i++){
        //     extraDataPre[m] = extra[i];
        //     m = m + 1;
        // }
        return newExtra;
    }

    function _verifyHeader(bytes memory rlpHeader)
        private
        view
        returns (
            bool ret,
            uint256 removeList,
            bytes[] memory addedPubKey
        )
    {
        blockHeader memory bh = _decodeHeader(rlpHeader);
        istanbulExtra memory ist = _decodeExtraData(bh.extraData);
        bh.extraData = _deleteAgg(ist, bh.extraData);
        bytes memory headerWithoutAgg = _encodeHeader(bh);
        bytes32 hash1 = keccak256(abi.encodePacked(headerWithoutAgg));
        bh.extraData = _deleteSealAndAgg(ist, bh.extraData);
        bytes memory headerWithoutSealAndAgg = _encodeHeader(bh);
        bytes32 hash2 = keccak256(abi.encodePacked(headerWithoutSealAndAgg));

        //the ecdsa seal signed by proposer
        ret = _verifySign(
            ist.seal,
            keccak256(abi.encodePacked(hash2)),
            bh.coinbase
        );
        if (ret == false) {
            revert("verifyEscaSign fail");
        }

        //the blockHash is the hash of the header without aggregated seal by validators.
        bytes memory blsMsg1 = _addsuffix(
            hash1,
            uint8(ist.aggregatedSeal.round)
        );
        if (bh.number % epochLength == 0) {
            //ret = verifyAggregatedSeal(allkey[nowEpoch],ist.aggregatedSeal.signature,blsMsg1);
            //it need to update validators at first block of new epoch.
            // changeValidators(ist.removeList,ist.addedPubKey);
            removeList = ist.removeList;
            addedPubKey = ist.addedPubKey;
        } else {
            //ret = verifyAggregatedSeal(allkey[nowEpoch],ist.aggregatedSeal.signature,blsMsg1);
        }
        // emit log("verify msg of AggregatedSeal",blsMsg1);

        //the parent seal need to pks of last epoch to verify parent seal,if block number is the first block or the second block at new epoch.
        //because, the parent seal of the first block and the second block is signed by validitors of last epoch.
        //and it need to not verify, when the block number is less than 2, the block is no parent seal.
        bytes memory blsMsg2 = _addsuffix(
            hash1,
            uint8(ist.aggregatedSeal.round)
        );
        if (bh.number > 1) {
            if (
                (bh.number - 1) % epochLength == 0 ||
                (bh.number) % epochLength == 0
            ) {
                //ret = verifyAggregatedSeal(allkey[nowEpoch-1],ist.parentAggregatedSeal.signature,blsMsg2);
            } else {
                //ret = verifyAggregatedSeal(allkey[nowEpoch],ist.parentAggregatedSeal.signature,blsMsg2);
            }
        }
        // emit log("verify msg of ParentAggregatedSeal",blsMsg2);
    }

    function _deleteAgg(istanbulExtra memory ist, bytes memory extraData)
        private
        pure
        returns (bytes memory newExtra)
    {
        bytes[] memory list1 = new bytes[](ist.validators.length);
        bytes[] memory list2 = new bytes[](ist.addedPubKey.length);
        for (uint256 i = 0; i < ist.validators.length; i++) {
            list1[i] = RLPEncode.encodeAddress(ist.validators[i]); //
            list2[i] = RLPEncode.encodeBytes(ist.addedPubKey[i]); //
        }

        bytes[] memory list = new bytes[](6);
        list[0] = RLPEncode.encodeList(list1); //
        list[1] = RLPEncode.encodeList(list2); //
        list[2] = RLPEncode.encodeUint(ist.removeList); //
        list[3] = RLPEncode.encodeBytes(ist.seal); //
        list[4] = new bytes(4);
        list[4][0] = bytes1(uint8(195));
        list[4][1] = bytes1(uint8(128));
        list[4][2] = bytes1(uint8(128));
        list[4][3] = bytes1(uint8(128));
        list[5] = _encodeAggregatedSeal(
            ist.parentAggregatedSeal.bitmap,
            ist.parentAggregatedSeal.signature,
            ist.parentAggregatedSeal.round
        );
        bytes memory b = RLPEncode.encodeList(list);
        newExtra = new bytes(b.length + 32);
        for (uint256 i = 0; i < b.length + 32; i++) {
            if (i < 32) {
                newExtra[i] = extraData[i];
            } else {
                newExtra[i] = b[i - 32];
            }
        }
    }

    function _deleteSealAndAgg(istanbulExtra memory ist, bytes memory extraData)
        private
        pure
        returns (bytes memory newExtra)
    {
        bytes[] memory list1 = new bytes[](ist.validators.length);
        bytes[] memory list2 = new bytes[](ist.addedPubKey.length);
        for (uint256 i = 0; i < ist.validators.length; i++) {
            list1[i] = RLPEncode.encodeAddress(ist.validators[i]); //
            list2[i] = RLPEncode.encodeBytes(ist.addedPubKey[i]); //
        }

        bytes[] memory list = new bytes[](6);
        list[0] = RLPEncode.encodeList(list1); //
        list[1] = RLPEncode.encodeList(list2); //
        list[2] = RLPEncode.encodeUint(ist.removeList); //
        list[3] = new bytes(1);
        list[3][0] = bytes1(uint8(128)); //
        list[4] = new bytes(4);
        list[4][0] = bytes1(uint8(195));
        list[4][1] = bytes1(uint8(128));
        list[4][2] = bytes1(uint8(128));
        list[4][3] = bytes1(uint8(128));
        list[5] = _encodeAggregatedSeal(
            ist.parentAggregatedSeal.bitmap,
            ist.parentAggregatedSeal.signature,
            ist.parentAggregatedSeal.round
        );
        bytes memory b = RLPEncode.encodeList(list);
        newExtra = new bytes(b.length + 32);
        for (uint256 i = 0; i < b.length + 32; i++) {
            if (i < 32) {
                newExtra[i] = extraData[i];
            } else {
                newExtra[i] = b[i - 32];
            }
        }
    }

    function _encodeAggregatedSeal(
        uint256 bitmap,
        bytes memory signature,
        uint256 round
    ) private pure returns (bytes memory output) {
        bytes memory output1 = RLPEncode.encodeUint(bitmap); //round
        bytes memory output2 = RLPEncode.encodeBytes(signature); //signature
        bytes memory output3 = RLPEncode.encodeUint(round); //bitmap

        bytes[] memory list = new bytes[](3);
        list[0] = output1;
        list[1] = output2;
        list[2] = output3;
        output = RLPEncode.encodeList(list);
    }

    function _verifySign(
        bytes memory seal,
        bytes32 hash,
        address coinbase
    ) private pure returns (bool) {
        //Signature storaged in extraData sub 27 after proposer signed.
        //So signature need to add 27 when verify it.
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(seal);
        v = v + 27;
        return coinbase == ecrecover(hash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    //suffix's rule is hash + round + commitMsg(the value is 2 usually);
    function _addsuffix(bytes32 hash, uint8 round)
        private
        pure
        returns (bytes memory)
    {
        bytes memory result = new bytes(34);
        for (uint256 i = 0; i < 32; i++) {
            result[i] = hash[i];
        }
        result[32] = bytes1(round);
        result[33] = bytes1(uint8(2));
        return result;
    }

    //it return binary data and the number of validator in the list.
    function _readRemoveList(uint256 r)
        private
        view
        returns (uint256[] memory ret, uint8 sum)
    {
        //the function transfer uint to binary.
        sum = 0;
        ret = new uint256[](keyNum);
        for (uint256 i = 0; r > 0; i++) {
            if (r % 2 == 1) {
                r = (r - 1) / 2;
                ret[i] = 1;
            } else {
                r = r / 2;
                ret[i] = 0;
                sum = sum + 1;
            }
        }
        //the current array is inverted.it needs to count down.
        for (uint256 i = 0; i < ret.length / 2; i++) {
            uint256 temp = ret[i];
            ret[i] = ret[ret.length - 1 - i];
            ret[ret.length - 1 - i] = temp;
        }
        return (ret, sum);
    }

    /** UUPS *********************************************************/
    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == _getAdmin(), "LightNode: only Admin can upgrade");
    }
}
