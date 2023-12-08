// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/security/PausableUpgradeable.sol";
import { SourceManager } from "./CrossChainUtils/SourceManager.sol";

contract DiscountManager is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable, SourceManager {

    enum Types { Inactive, TimeBased, StaticBased }

    struct Discount {
        address owner;
        Types discountType; 
    }

    mapping(bytes32 => Discount) public nameToDiscount;
    mapping(bytes32 => uint256[]) public discountChainIds;

    mapping(bytes32 => mapping(address => uint256)) public discountToClaimBalance;

    event DiscountInitialized(address owner, string discountName, Types discountType);

    function initialize(address _ccipRouter) initializer public {
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __SourceManager_init(_ccipRouter);
    }


    function initializeDiscount(string calldata tokenName, Types tokenType) public {

        require(uint8(tokenType) == 1 || uint8(tokenType) == 2, "Invalid token type");

        require(bytes(tokenName).length <= 32, "Token name is too long");
        bytes32 name = getBytesString(tokenName);

        Discount storage discount = nameToDiscount[name];
        require(discount.discountType == Types.Inactive, "Token already initialized");

        discount.owner = msg.sender;
        discount.discountType = tokenType;

        emit DiscountInitialized(msg.sender, tokenName, tokenType);
    }


    function createStaticDiscount(string memory tokenName, string memory tokenSymbol, uint256[] memory tokenIds, string[] memory uris, uint256 chainId) public payable {

        bytes32 name = getBytesString(tokenName);
        Discount memory discount = nameToDiscount[name];

        require(
            discount.owner == msg.sender, "Caller is not token owner"
        );

        require(
            discount.discountType == Types.StaticBased,
            "Invalid discount type. Expected Types.StaticBased"
        );

        
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

        discountChainIds[name].push(chainId);
    
    }




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



    /**
     * @notice Convert a string into a bytes32 value.
     * @param name The input string to be converted.
     * @return _name The resulting bytes32 value.
     */
    function getBytesString(string memory name) private pure returns(bytes32 _name) {
        assembly {
            _name := mload(add(name, 32))
        }
    }


    function _authorizeUpgrade(address newImplementation)
        internal onlyOwner override {
    }

}