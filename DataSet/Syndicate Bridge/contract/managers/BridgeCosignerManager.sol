// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../interfaces/IBridgeCosignerManager.sol";

contract BridgeCosignerManager is ERC165, Ownable, IBridgeCosignerManager {
    using ECDSA for bytes32;

    uint8 public constant MIN_COSIGNER_REQUIRED = 2;
    mapping(address => Cosigner) internal _cosigners;
    mapping(uint256 => address[]) internal _cosaddrs;

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IBridgeCosignerManager).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function addCosigner(address cosaddr, uint256 chainId)
        public
        override
        onlyOwner
    {
        Cosigner memory cosigner = _cosigners[cosaddr];
        require(!cosigner.active, "BCM: ALREADY_EXIST");
        require(cosaddr != address(0), "BCM: ZERO_ADDRESS");

        uint256 currentChainId;
        assembly {
            currentChainId := chainid()
        }
        require(currentChainId != chainId, "BCM: ONLY_EXTERNAL");

        _cosaddrs[chainId].push(cosaddr);
        _cosigners[cosaddr] = Cosigner(
            cosaddr,
            chainId,
            _cosaddrs[chainId].length - 1,
            true
        );

        emit CosignerAdded(cosaddr, chainId);
    }

    function addCosignerBatch(address[] calldata cosaddrs, uint256 chainId)
        public
        override
        onlyOwner
    {
        require(cosaddrs.length != 0, "BCM: EMPTY_BATCH");

        for (uint256 i = 0; i < cosaddrs.length; i++) {
            addCosigner(cosaddrs[i], chainId);
        }
    }

    function removeCosigner(address cosaddr) public override onlyOwner {
        require(cosaddr != address(0), "BCM: ZERO_ADDRESS");
        Cosigner memory cosigner = _cosigners[cosaddr];
        require(cosigner.active, "BCM: NOT_EXIST");

        address[] storage addrs = _cosaddrs[cosigner.chainId];

        if (addrs.length > 1) {
            // move last to rm slot
            addrs[cosigner.index] = _cosaddrs[cosigner.chainId][
                addrs.length - 1
            ];
            addrs.pop();

            // change indexing
            address cosaddrLast = addrs[cosigner.index];
            _cosigners[cosaddrLast].index = cosigner.index;
        } else {
            // just remove it as 1 left
            addrs.pop();
        }

        delete _cosigners[cosaddr];

        emit CosignerRemoved(cosigner.addr, cosigner.chainId);
    }

    function removeCosignerBatch(address[] calldata cosaddrs)
        public
        override
        onlyOwner
    {
        require(cosaddrs.length == 0, "BCM: EMPTY_BATCH");

        for (uint256 i = 0; i < cosaddrs.length; i++) {
            removeCosigner(cosaddrs[i]);
        }
    }

    function getCosigners(uint256 chainId)
        public
        view
        override
        returns (address[] memory)
    {
        return _cosaddrs[chainId];
    }

    function getCosignCount(uint256 chainId)
        public
        view
        override
        returns (uint8)
    {
        uint8 voteCount = (uint8(_cosaddrs[chainId].length) * 2) / 3; // 67%
        return
            MIN_COSIGNER_REQUIRED >= voteCount
                ? MIN_COSIGNER_REQUIRED
                : voteCount;
    }

    function recover(bytes32 hash, bytes calldata signature)
        internal
        pure
        returns (address)
    {
        return hash.toEthSignedMessageHash().recover(signature);
    }

    function verify(
        bytes32 commitment,
        uint256 chainId,
        bytes[] calldata signatures
    ) external view override returns (bool) {
        uint8 _required = getCosignCount(chainId);
        if (_required > signatures.length) {
            return false;
        }

        address[] memory cached = new address[](signatures.length);
        uint8 signersMatch;

        for (uint8 i = 0; i < signatures.length; i++) {
            address signer = recover(commitment, signatures[i]);
            Cosigner memory cosigner = _cosigners[signer];

            if (
                cosigner.active &&
                cosigner.chainId == chainId &&
                !_inCache(cached, signer)
            ) {
                signersMatch++;
                cached[i] = signer;
                if (signersMatch == _required) return true;
            }
        }

        return false;
    }

    function _inCache(address[] memory cached, address signer)
        internal
        pure
        returns (bool hasCache)
    {
        for (uint8 j = 0; j < cached.length; j++) {
            if (cached[j] == signer) {
                hasCache = true;
                break;
            }
            // prevent iteration if cache not updated in slot
            if (cached[j] == address(0)) {
                break;
            }
        }
    }
}
