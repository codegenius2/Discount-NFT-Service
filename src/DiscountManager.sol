// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/security/PausableUpgradeable.sol";
import { SourceManager } from "./CrossChainUtils/SourceManager.sol";

/**
 * @title DiscountManager
 * @dev Manages various types of discounts and balances, including time-based and static-based discounts, with Chainlink CCIP integration.
 */
contract DiscountManager is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable, SourceManager {

    // Enumeration for types of discounts
    enum Types { Inactive, TimeBased, StaticBased }

    struct Discount {
        address owner;
        Types discountType; 
    }

    // Mapping from discount name to Discount struct
    mapping(bytes32 => Discount) public nameToDiscount;
 
    // Mapping from discount name to chain IDs supported for the token
    mapping(bytes32 => mapping(uint256 => bool)) public discountChainIds;

    // Mapping from discount name to a mapping of addresses and their corresponding claim balances
    // discount name => userAddress => discountId => claim balance
    mapping(bytes32 => mapping(address => mapping(uint256 => uint256))) public discountToClaimBalance;


    event DiscountInitialized(address owner, string discountName, Types discountType);
    event DiscountCreated(string discountName, Types discountType, uint256 chainId);
    event DiscountClaimed(string discountName, uint256 discountId, uint256 chainId, Types discountType);
    event UsersBalancesIncremented(string discountName, address[] users);


    /**
     * @dev Initializes the DiscountManager and sourceManager contract.
     * @param _ccipRouter The address of the Chainlink CCIP Router contract.
     */
    function initialize(address _ccipRouter) initializer public {
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __SourceManager_init(_ccipRouter);
    }


    /**
     * @dev Initializes a discount with the specified name and type.
     * @param tokenName The name of the discount token.
     * @param tokenType The type of the discount (TimeBased or StaticBased).
     */
    function initializeDiscount(string calldata tokenName, Types tokenType) public {

        require(uint8(tokenType) == 1 || uint8(tokenType) == 2, "Invalid token type");

        require(bytes(tokenName).length <= 32, "Token name is too long");
        bytes32 name = _getBytesString(tokenName);

        Discount storage discount = nameToDiscount[name];
        require(discount.discountType == Types.Inactive, "Token already initialized");

        discount.owner = msg.sender;
        discount.discountType = tokenType;

        emit DiscountInitialized(msg.sender, tokenName, tokenType);
    }


    /**
     * @dev Creates a static-based discount with the specified parameters.
     * @param tokenName The name of the discount token.
     * @param tokenSymbol The symbol of the discount token.
     * @param tokenIds An array of token IDs associated with the discount.
     * @param uris An array of URIs associated with the discount.
     * @param chainId The Chain ID where the discount is created.
     */
    function createStaticDiscount(string memory tokenName, string memory tokenSymbol, uint256[] memory tokenIds, string[] memory uris, uint256 chainId) public payable {

        bytes32 name = _getBytesString(tokenName);
        Discount memory discount = nameToDiscount[name];

        require(discount.owner == msg.sender, "Caller is not token owner");
        require(discount.discountType == Types.StaticBased, "Invalid discount type. Expected Types.StaticBased");

        
        bytes memory data = abi.encodeWithSignature(
            "createStaticDiscount(string,string,uint256[],string[])", 
            tokenName, tokenSymbol, tokenIds, uris
        );

        // create ccip message to send the receive contract
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(data, chainId);

        // check the caller send enogh msg value for ccip
        uint256 fee = _getCCIPMessageFee(message, chainId);
        require(msg.value >= fee, "Insufficient value");

        // send the message and create the discount
        _sendCCIPMessage(message, chainId);

        discountChainIds[name][chainId] = true;
        emit DiscountCreated(tokenName, Types.StaticBased, chainId);
    
    }


    /**
     * @dev Calculates the fee required to create a static-based discount with the specified parameters.
     * @param tokenName The name of the discount token.
     * @param tokenSymbol The symbol of the discount token.
     * @param tokenIds An array of token IDs associated with the discount.
     * @param uris An array of URIs associated with the discount.
     * @param chainId The Chain ID where the discount is created.
     * @return fee The fee required to send the Chainlink CCIP message and create the discount.
     */
    function getCreateStaticDiscountFee(
        string calldata tokenName, string calldata tokenSymbol, 
        uint256[] calldata tokenIds, string[] calldata uris, uint256 chainId) public view returns(uint256 fee) {
        
        bytes memory data = abi.encodeWithSignature(
            "createStaticDiscount(string,string,uint256[],string[])", 
            tokenName, tokenSymbol, tokenIds, uris
        );

        // create ccip message to send the receive contract
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(data, chainId);

        // returns the fee for sending the ccip message
        fee = _getCCIPMessageFee(message, chainId);
    }


    function batchIncrementUsersBalances(string calldata tokenName, uint256 discountId, address[] calldata addresses) public {

        bytes32 name = _getBytesString(tokenName);

        Discount memory discount = nameToDiscount[name];

        require(discount.owner == msg.sender, "Caller is not token owner");
        require(discount.discountType != Types.Inactive, "Discount is not active");

        uint256 length = addresses.length;

        for(uint256 index; index < length; index++) {

            address user = addresses[index];
            discountToClaimBalance[name][user][discountId] += 1;
        }

        emit UsersBalancesIncremented(tokenName, addresses);
    }


    function getClaimStaticDiscountFee(string memory tokenName, uint256 discountId, uint256 chainId) public view returns(uint256 fee) {
        
        bytes memory data = abi.encodeWithSignature(
            "mintStaticDiscount(string,address,uint256,uint256)", 
            tokenName, msg.sender, discountId, 1
        );

        // create ccip message to send the receive contract
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(data, chainId);

        // returns the fee for sending the ccip message
        fee = _getCCIPMessageFee(message, chainId);

    }


    function claimStaticDiscount(string memory tokenName, uint256 discountId, uint256 chainId) public payable {

        bytes32 name = _getBytesString(tokenName);
        Discount memory discount = nameToDiscount[name];
        
        require(discount.discountType == Types.StaticBased, "Discount is not static based");
        require(discountToClaimBalance[name][msg.sender][discountId] > 0, "Caller is not eligible to claim");

        bytes memory data = abi.encodeWithSignature(
            "mintStaticDiscount(string,address,uint256,uint256)", 
            tokenName, msg.sender, discountId, 1
        );

        // create ccip message to send the receive contract
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(data, chainId);

        uint256 ccipFee = _getCCIPMessageFee(message, chainId);
        require(msg.value >= ccipFee, "Insufficient message value");

        _sendCCIPMessage(message, chainId);
        emit DiscountClaimed(tokenName, discountId, chainId, Types.StaticBased);
    }


    /**
     * @notice Convert a string into a bytes32 value.
     * @param name The input string to be converted.
     * @return _name The resulting bytes32 value.
     */
    function _getBytesString(string memory name) private pure returns(bytes32 _name) {
        assembly {
            _name := mload(add(name, 32))
        }
    }


    function _authorizeUpgrade(address newImplementation)
        internal onlyOwner override {
    }

}