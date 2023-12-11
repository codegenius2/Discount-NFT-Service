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
    function initializeDiscount(string calldata tokenName, Types tokenType) external {

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
    function createStaticDiscount(string memory tokenName, string memory tokenSymbol, uint256[] memory tokenIds, string[] memory uris, uint256 chainId) external payable {

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
        uint256[] calldata tokenIds, string[] calldata uris, uint256 chainId) external view returns(uint256 fee) {
        
        bytes memory data = abi.encodeWithSignature(
            "createStaticDiscount(string,string,uint256[],string[])", 
            tokenName, tokenSymbol, tokenIds, uris
        );

        // create ccip message to send the receive contract
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(data, chainId);

        // returns the fee for sending the ccip message
        fee = _getCCIPMessageFee(message, chainId);
    }


    /**
     * @notice Batch increments claim balances for multiple users associated with a specific discount.
     * @dev This function allows the owner of a discount to increment the claim balances for multiple users,
     * making them eligible for claiming the discount later.
     * @param tokenName The name of the discount token.
     * @param discountId The id for the discount.
     * @param addresses An array of user addresses whose claim balances will be incremented.
     * @dev The caller must be the owner of the discount, and the discount must be active (not Inactive).
     * @dev For each address in the provided array, the claim balance for the specified discount is increased by 1.
     * @dev Emits an event to signal the successful increment of claim balances for the specified users.
     */
    function batchIncrementUsersBalances(string calldata tokenName, uint256 discountId, address[] calldata addresses) external {

        bytes32 name = _getBytesString(tokenName);

        Discount memory discount = nameToDiscount[name];

        // Check ownership and discount activity status
        require(discount.owner == msg.sender, "Caller is not token owner");
        require(discount.discountType != Types.Inactive, "Discount is not active");

        uint256 length = addresses.length;

        // Iterate through the provided addresses and increment claim balances
        for(uint256 index; index < length; index++) {
            address user = addresses[index];
            discountToClaimBalance[name][user][discountId] += 1;
        }

        emit UsersBalancesIncremented(tokenName, addresses);
    }


    /**
     * @notice returns the fee required to claim a static-based discount for a specific user.
     * @dev This function computes the Chainlink CCIP message fee needed to claim a static-based discount
     * with the specified parameters for the calling user.
     * @param tokenName The name of the discount token.
     * @param discountId The unique identifier for the discount.
     * @param chainId The Chain ID where the discount wants to create and receive.
     * @return fee The fee required to send the Chainlink CCIP message and claim the discount.
     * @dev It generates a CCIP message with the 'mintStaticDiscount' function signature,
     * calculates the message fee, and returns the result.
     */
    function getClaimStaticDiscountFee(string memory tokenName, uint256 discountId, uint256 chainId) external view returns(uint256 fee) {
        
        bytes memory data = abi.encodeWithSignature(
            "mintStaticDiscount(string,address,uint256,uint256)", 
            tokenName, msg.sender, discountId, 1
        );

        // create ccip message to send the receive contract
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(data, chainId);

        // returns the fee for sending the ccip message
        fee = _getCCIPMessageFee(message, chainId);

    }


    


    /**
     * @notice Claims a static-based discount for the calling user on a specific Chain ID.
     * @dev This function allows users to claim a static-based discount associated with their address
     * on the specified Chain ID by sending a Chainlink CCIP message.
     * @param tokenName The name of the discount token.
     * @param discountId The unique identifier for the discount.
     * @param chainId The Chain ID where the discount wants to create and receive.
     * @dev The discount must be supported on the given Chain ID, and the discount type must be Types.StaticBased.
     * @dev The user must have a positive claim balance for the specified discount to be eligible to claim.
     * @dev The function emits a DiscountClaimed event upon successful claim.
     */
    function claimStaticDiscount(string memory tokenName, uint256 discountId, uint256 chainId) external payable {

        bytes32 name = _getBytesString(tokenName);
        
        // Check if the discount is supported on the given Chain ID
        require(discountChainIds[name][chainId] == true, "Chain not supported");
        
        // Retrieve discount information
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
        
        // decrement user token balance
        discountToClaimBalance[name][msg.sender][discountId] -= 1;

        // Send the CCIP message to mint on destination and emit the DiscountClaimed event
        _sendCCIPMessage(message, chainId);
        emit DiscountClaimed(tokenName, discountId, chainId, Types.StaticBased);
    }



    /**
     * @notice Creates a time-based discount contract with the specified parameters.
     * @dev This function allows the owner of a discount to create a time-based discount contract on a specific Chain ID
     * by sending a Chainlink CCIP message with the provided token information and expiration metadata.
     * @param tokenName The name of the discount token.
     * @param tokenSymbol The symbol of the discount token.
     * @param expireMetadata Metadata indicating the expiration details of the time-based discount.
     * @param chainId The Chain ID where the discount is created.
     * @dev The caller must be the owner of the discount, and the discount type must be Types.TimeBased.
     * @dev Emits a DiscountCreated event upon successful creation.
     */
    function createTimeBasedDiscount(string memory tokenName, string memory tokenSymbol, string memory expireMetadata, uint256 chainId) external payable {

        bytes32 name = _getBytesString(tokenName);
        Discount memory discount = nameToDiscount[name];

        require(discount.owner == msg.sender, "Caller is not token owner");
        require(discount.discountType == Types.TimeBased, "Invalid discount type. Expected Types.TimeBased");

    
        bytes memory data = abi.encodeWithSignature(
            "createTimeBasedDiscount(string,string,string)", 
            tokenName, tokenSymbol, expireMetadata
        );

        // create ccip message to send the receive contract
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(data, chainId);

        // returns the fee for sending the ccip message
        uint256 fee = _getCCIPMessageFee(message, chainId);
        require(msg.value >= fee, "Insufficient message value");

        // send the message and create the discount
        _sendCCIPMessage(message, chainId);

        discountChainIds[name][chainId] = true;
        emit DiscountCreated(tokenName, Types.TimeBased, chainId);
    
    }


    /**
     * @dev Returns the fee required to create a time-based discount contract with the specified parameters.
     * @param tokenName The name of the discount contract token.
     * @param tokenSymbol The symbol of the discount token.
     * @param expireMetadata an string of the expired imaged for discounts.
     * @param chainId The Chain ID where the discount is created.
     * @return fee The fee required to send the Chainlink CCIP message and create the discount contract.
     */
    function getCreateTimeBasedDiscountFee(
        string memory tokenName, string memory tokenSymbol, string memory expireMetadata, uint256 chainId) external view returns(uint256 fee) {
        
        bytes memory data = abi.encodeWithSignature(
            "createTimeBasedDiscount(string,string,string)", 
            tokenName, tokenSymbol, expireMetadata
        );

        // create ccip message to send the receive contract
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(data, chainId);

        // returns the fee for sending the ccip message
        fee = _getCCIPMessageFee(message, chainId);
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