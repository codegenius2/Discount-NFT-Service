// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/security/PausableUpgradeable.sol";


contract DiscountManager is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {


    struct Discount {
        address owner;
        address timeBased;
        address staticBased;
    }
    
    address public ccipRouter;

    uint64 chainSelector;
    address public bcsReceiver;

    mapping(bytes32 => Discount) public nameToDiscount;
    mapping(bytes32 => mapping(address => uint256)) public discountToClaimBalance;

    event MessageSent(bytes32 messageId);


    function initialize(address _ccipRouter, uint64 _chainSelector, address reveiver) initializer public {
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        ccipRouter = _ccipRouter;
        chainSelector = _chainSelector;
        bcsReceiver = reveiver;
    }


    function createStaticDiscount(string memory tokenName, string memory tokenSymbol, uint256[] memory tokenIds, string[] memory uris) public payable {

        require(bytes(tokenName).length <= 32, "Token name is too long");
        bytes32 name = getBytesString(tokenName);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(bcsReceiver),
            data: abi.encodeWithSignature(
                "createStaticDiscount(string,string,uint256[],string[])", 
                tokenName, tokenSymbol, tokenIds, uris
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 4_000_000})
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(ccipRouter).getFee(
            chainSelector,
            message
        );

        require(msg.value >= fee, "Insufficient value");

        bytes32 messageId = IRouterClient(ccipRouter).ccipSend{value: fee}(
            chainSelector,
            message
        );
        
        emit MessageSent(messageId);

    
    }


    function getCreateStaticDiscountFee(
        string calldata tokenName, string calldata tokenSymbol, 
        uint256[] calldata tokenIds, string[] calldata uris) public view returns(uint256 fee) {
            
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(bcsReceiver),
            data: abi.encodeWithSignature(
                "createStaticDiscount(string,string,uint256[],string[])", 
                tokenName, tokenSymbol, tokenIds, uris
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 4_000_000})
            ),
            feeToken: address(0)
        });

        fee = IRouterClient(ccipRouter).getFee(
            chainSelector,
            message
        );
    }



    /**
     * @notice Convert a string into a bytes32 value.
     * @param name The input string to be converted.
     * @return _name The resulting bytes32 value.
     */
    function getBytesString(string memory name) internal pure returns(bytes32 _name) {
        assembly {
            _name := mload(add(name, 32))
        }
    }


    function _authorizeUpgrade(address newImplementation)
        internal onlyOwner override {
    }

}