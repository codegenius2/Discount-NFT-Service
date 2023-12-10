// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/token/ERC1155/ERC1155Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/security/PausableUpgradeable.sol";
import { ERC1155BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import { ERC1155SupplyUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ERC1155 Discount Minter
 * @dev This contract is an ERC1155-based discount service that sits on top of a discount manager.
 * It enables users to difine a discount, where the token ID represents the discount percentage for each minted item.
 * Note: this discount contract will be created for each user(project) through discount manager.
 */
contract StaticDiscount is Initializable, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {

    string public name;
    string public symbol;


    // mapping form tokenId to token metadata 
    mapping(uint256 => string) tokenIdToMetadata;


    event DiscountMinted(address reciever, address discount, uint256 discountId);
    event DiscountBurned(address owner, address discount, uint256 discountId);


    /**
     * @dev Initializes the DiscountService contract, setting the initial owner as the Minter Role,
     * and specifying the discount name, and symbol.
     * @param tokenName The name of the ERC1155 tokens.
     * @param tokenSymbol The symbol of the ERC1155 tokens.
     */
    function initialize(string memory tokenName, string memory tokenSymbol, uint256[] memory tokenIds, string[] memory uris) initializer public {
        __ERC1155_init(name);
        __Ownable_init();
        __Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();
        batchSetURI(tokenIds, uris);
        name = tokenName;
        symbol = tokenSymbol;     
    }


    /**
     * @dev Sets the URI for a specific token ID, allowing the association of metadata with each token.
     * @param tokenId The ID of the token for which to set the URI.
     * @param newuri The URI to set for the token.
     */    
    function _setURI(uint256 tokenId, string memory newuri) private {
        tokenIdToMetadata[tokenId] = newuri;
    }


    /**
     * @dev Sets the URI for a list of token IDs, allowing the association of metadata with each token.
     * @param tokenIds The ID of the token for which to set the URI.
     * @param uris The URI to set for the token.
     */   
    function batchSetURI(uint256[] memory tokenIds, string[] memory uris) public onlyOwner {

        require(tokenIds.length == uris.length, "Invalid arrays length");

        uint256 length = tokenIds.length;
        for(uint index; index < length; index++) {
            _setURI(tokenIds[index], uris[index]);
        }
    }


    /**
     * @dev Retrieves the URI for a specific token ID.
     * @param id The ID of the token for which to retrieve the URI.
     * @return The URI associated with the token.
     */
    function uri(uint256 id ) public view override returns (string memory) {
        return tokenIdToMetadata[id];
    }


    /**
     * @dev Mints a single token id for a specified account.
     * @param account The address to receive the minted token.
     * @param id The token ID to be minted.
     * @param amount The number of tokens to mint.
     * @param data Additional data to include with the mint.
     */
    function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        _mint(account, id, amount, data);
        emit DiscountMinted(account, address(this), id);
    }


    /**
     * @dev burn a single discount for a specified account.
     * @param account The address of discount owner.
     * @param id The token ID to be burned.
     * @param value The number of tokens to burn.
     */
    function burn(address account, uint256 id, uint256 value) public override {
        super.burn(account, id, value);
        emit DiscountBurned(account, address(this), id);
    }
    

    /**
     * @dev Mints multiple tokens for a specified account.
     * @param to The address to receive the minted tokens.
     * @param ids An array of token IDs to be minted.
     * @param amounts An array of corresponding token amounts to mint.
     * @param data Additional data to include with the mint.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev Pauses the contract, restricted to the owner.
     */
    function pause() public onlyOwner {
        _pause();
    }


    /**
     * @dev Unpauses the contract, restricted to the owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }


    function _safeTransferFrom(
        address from, address to, uint256 id, uint256 amount, bytes memory data
    ) internal override {
        super._safeTransferFrom(from, to, id, amount, data);

    }


    function _safeBatchTransferFrom(
        address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data
    ) internal override {
        super._safeBatchTransferFrom(from, to, ids, amounts, data);
    }


    /* this function is require by solidity to override */
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal whenNotPaused override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }


    function _authorizeUpgrade(address newImplementation)
        internal onlyOwner override {
    }

}