// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/token/ERC1155/ERC1155Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/security/PausableUpgradeable.sol";
import { ERC1155BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import { ERC1155SupplyUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/UUPSUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/utils/CountersUpgradeable.sol";


/**
 * @title ERC1155 Discount Minter
 * @dev This contract is an ERC1155-based discount service that sits on top of a discount manager.
 * It enables users to difine a discount, where the token ID represents the discount percentage for each minted item.
 * The configured tokens can be utilized during a fixed time frame, after the discount will expire.
 * Note: this discount minter contract will be created for each user(project) through discount manager.
 */
contract TimeBasedDiscount is Initializable, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {
    
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenId;

    // the expired metadata uri
    string expiredMetadata;

    // contract name and symbol
    string public name;
    string public symbol;


    struct Discount {
        bool isActive;
        uint64 ratio;
        uint64 startAt;
        uint64 endAt;
    }


    // mapping from tokenId to discount info
    mapping(uint256 => Discount) tokenIdToDiscount;


    // mapping form tokenId to token metadata 
    mapping(uint256 => string) tokenIdToMetadata;


    // list of defined token Ids
    uint256[] public activeTokenIds;


    event DiscountCreated(
        uint256 tokenId,
        uint64 ratio,
        uint64 startAt, 
        uint64 endAt
    );

    event DiscountMinted(
        uint256 tokenId, 
        uint256 amount, 
        address receiver
    );



    /**
     * @dev Initializes the DiscountService contract, setting the initial owner as the Minter Role,
     * and specifying the discount name, and symbol.
     * @param tokenName The name of the ERC1155 tokens.
     * @param tokenSymbol The symbol of the ERC1155 tokens.
     */
    function initialize(string calldata tokenName, string calldata tokenSymbol) initializer public {
        __ERC1155_init(name);
        __Ownable_init();
        __Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();
        name = tokenName;
        symbol = tokenSymbol;     
        _tokenId.increment();
    }


       
    function createToken(string calldata newUri, uint64 startAt, uint64 endAt, uint64 ratio) public onlyOwner {
        
        require(ratio > 0 && ratio <= 100, "Invalid ratio");
        require(startAt >= block.timestamp, "Invalid startAt timestamp");
        require(endAt > startAt, "Invalid endAt timestamp");


        uint256 newTokenId = _tokenId.current();
        Discount memory discount = Discount(
            true,
            ratio,
            startAt,
            endAt
        );

        tokenIdToDiscount[newTokenId] = discount;
        tokenIdToMetadata[newTokenId] = newUri;

        _tokenId.increment();
        emit DiscountCreated(newTokenId, ratio, startAt, endAt);
        
    }


    function _isExpiretionNeeded(uint256 tokenId) private view returns(bool isNeeded) {

        Discount memory discount = tokenIdToDiscount[tokenId];
        isNeeded = (discount.endAt >= block.timestamp) && (discount.isActive == true);
    }


    function getExpireNeededTokenIds() public view returns(uint256[] memory tokenIds) {

        uint256 lastTokenId = _tokenId.current();
        uint256 id = 1;
        uint256 index = 0;

        for(; id < lastTokenId; id++) {

            if(_isExpiretionNeeded(id)) {
                tokenIds[index] = id;
                index = index + 1;
            }
        }

    }


    function expireDiscountByTokenId(uint256 tokenId) internal {

        require(tokenIdToDiscount[tokenId].endAt >= block.timestamp);
        tokenIdToMetadata[tokenId] = expiredMetadata;
        tokenIdToDiscount[tokenId].isActive = false;
    }


    function expireDiscountByListOfTokenIds(uint256[] memory tokenIds) internal {

        uint lastIndex = tokenIds.length;
        require(lastIndex > 0, "Invalid array");

        for(uint i; i < lastIndex; i++) {
            
            uint256 tokenId = tokenIds[i];
            expireDiscountByTokenId(tokenId);
        }

    }


    function getDiscountRatio(uint256 tokenId) public view returns(uint256 ratio) {

        Discount memory discount = tokenIdToDiscount[tokenId];
        ratio = discount.isActive? discount.ratio : 0;
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
    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public onlyOwner
    {
        _mint(account, id, amount, data);
    }
    

    /**
     * @dev Mints multiple tokens for a specified account.
     * @param to The address to receive the minted tokens.
     * @param ids An array of token IDs to be minted.
     * @param amounts An array of corresponding token amounts to mint.
     * @param data Additional data to include with the mint.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public onlyOwner
    {
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