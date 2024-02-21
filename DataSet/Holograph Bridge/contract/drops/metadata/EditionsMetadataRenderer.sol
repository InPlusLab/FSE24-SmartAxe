// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../../abstract/Initializable.sol";

import {IMetadataRenderer} from "../interface/IMetadataRenderer.sol";
import {IHolographDropERC721} from "../interface/IHolographDropERC721.sol";
import {ERC721Metadata} from "../../interface/ERC721Metadata.sol";
import {NFTMetadataRenderer} from "../utils/NFTMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "./MetadataRenderAdminCheck.sol";

import {Configuration} from "../struct/Configuration.sol";

interface DropConfigGetter {
  function config() external view returns (Configuration memory config);
}

/// @notice EditionsMetadataRenderer for editions support
contract EditionsMetadataRenderer is Initializable, IMetadataRenderer, MetadataRenderAdminCheck {
  /// @notice Storage for token edition information
  struct TokenEditionInfo {
    string description;
    string imageURI;
    string animationURI;
  }

  /// @notice Event for updated Media URIs
  event MediaURIsUpdated(address indexed target, address sender, string imageURI, string animationURI);

  /// @notice Event for a new edition initialized
  /// @dev admin function indexer feedback
  event EditionInitialized(address indexed target, string description, string imageURI, string animationURI);

  /// @notice Description updated for this edition
  /// @dev admin function indexer feedback
  event DescriptionUpdated(address indexed target, address sender, string newDescription);

  /// @notice Token information mapping storage
  mapping(address => TokenEditionInfo) public tokenInfos;

  /**
   * @notice Used internally to initialize the contract instead of through a constructor
   * @dev This function is called by the deployer/factory when creating a contract
   * @dev A blank init function is required to be able to call genesisDeriveFutureAddress to get the deterministic address
   * @dev Since no data is required to be intialized the selector is just returned and _setInitialized() does not need to be called
   */
  function init(bytes memory /* initPayload */) external pure override returns (bytes4) {
    return InitializableInterface.init.selector;
  }

  /// @notice Update media URIs
  /// @param target target for contract to update metadata for
  /// @param imageURI new image uri address
  /// @param animationURI new animation uri address
  function updateMediaURIs(
    address target,
    string memory imageURI,
    string memory animationURI
  ) external requireSenderAdmin(target) {
    tokenInfos[target].imageURI = imageURI;
    tokenInfos[target].animationURI = animationURI;
    emit MediaURIsUpdated({target: target, sender: msg.sender, imageURI: imageURI, animationURI: animationURI});
  }

  /// @notice Admin function to update description
  /// @param target target description
  /// @param newDescription new description
  function updateDescription(address target, string memory newDescription) external requireSenderAdmin(target) {
    tokenInfos[target].description = newDescription;

    emit DescriptionUpdated({target: target, sender: msg.sender, newDescription: newDescription});
  }

  /// @notice Default initializer for edition data from a specific contract
  /// @param data data to init with
  function initializeWithData(bytes memory data) external {
    // data format: description, imageURI, animationURI
    (string memory description, string memory imageURI, string memory animationURI) = abi.decode(
      data,
      (string, string, string)
    );

    tokenInfos[msg.sender] = TokenEditionInfo({
      description: description,
      imageURI: imageURI,
      animationURI: animationURI
    });
    emit EditionInitialized({
      target: msg.sender,
      description: description,
      imageURI: imageURI,
      animationURI: animationURI
    });
  }

  /// @notice Contract URI information getter
  /// @return contract uri (if set)
  function contractURI() external view override returns (string memory) {
    address target = msg.sender;
    TokenEditionInfo storage editionInfo = tokenInfos[target];
    Configuration memory config = DropConfigGetter(target).config();

    return
      NFTMetadataRenderer.encodeContractURIJSON({
        name: ERC721Metadata(target).name(),
        description: editionInfo.description,
        imageURI: editionInfo.imageURI,
        animationURI: editionInfo.animationURI,
        royaltyBPS: uint256(config.royaltyBPS),
        royaltyRecipient: config.fundsRecipient
      });
  }

  /// @notice Token URI information getter
  /// @param tokenId to get uri for
  /// @return contract uri (if set)
  function tokenURI(uint256 tokenId) external view override returns (string memory) {
    address target = msg.sender;

    TokenEditionInfo memory info = tokenInfos[target];
    IHolographDropERC721 media = IHolographDropERC721(target);

    uint256 maxSupply = media.saleDetails().maxSupply;

    // For open editions, set max supply to 0 for renderer to remove the edition max number
    // This will be added back on once the open edition is "finalized"
    if (maxSupply == type(uint64).max) {
      maxSupply = 0;
    }

    return
      NFTMetadataRenderer.createMetadataEdition({
        name: ERC721Metadata(target).name(),
        description: info.description,
        imageURI: info.imageURI,
        animationURI: info.animationURI,
        tokenOfEdition: tokenId,
        editionSize: maxSupply
      });
  }
}
