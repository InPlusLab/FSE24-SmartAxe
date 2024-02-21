// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract NFTToken is ERC721Enumerable, Ownable {
    string public baseURI;
    mapping(uint256 => string) private _tokenURIs;
    address _nativeContract;
    uint _nativeChain;

    constructor (string memory name_, string memory symbol_, address nativeContract_, uint nativeChain_) ERC721(name_, symbol_) {
        _nativeContract = nativeContract_;
        _nativeChain = nativeChain_;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _setBaseURI(string memory baseURI_) internal {
        baseURI = baseURI_;
    }

    function nativeContract() public view returns (address) {
        return _nativeContract;
    }

    function nativeChain() public view returns (uint) {
        return _nativeChain;
    }

    function mint(address to, uint256 tokenId) external onlyOwner {
        if (!_exists(tokenId)) {
            _mint(to, tokenId);
        } else {
            _transfer(address(this), to, tokenId);
        }
    }

    function brun(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }

    function lock(address from,uint256 tokenId) external onlyOwner {
        _transfer(from, address(this), tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyOwner {
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _setBaseURI(baseURI_);
    }

    function safeMint(address to, uint256 tokenId, bytes memory _data) external onlyOwner {
        _safeMint(to, tokenId, _data);
    }

    function multiMint(address[] memory tos, uint256[] memory tokenIds) external onlyOwner {
        require(tos.length == tokenIds.length, "illegal length");
        for (uint i = 0; i < tos.length; i ++) {
            _mint(tos[i], tokenIds[i]);
        }
    }

    function multiMintStart(address to, uint256 start, uint256 end) external onlyOwner {
        for (uint i = start; i <= end; i++) {
            _mint(to, i);
        }
    }

    function multiSafeMint(address[] memory tos, uint256[] memory tokenIds, bytes memory _data) external onlyOwner {
        require(tos.length == tokenIds.length, "illegal length");
        for (uint i = 0; i < tos.length; i ++) {
            _safeMint(tos[i], tokenIds[i], _data);
        }
    }
}