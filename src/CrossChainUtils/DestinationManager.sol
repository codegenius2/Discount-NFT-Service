// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts@4.9.1/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts@4.9.1/access/Ownable.sol";
import {IStaticDiscount} from "../interfaces/IStaticDiscount.sol";
import {ITimeBasedDiscount} from "../interfaces/ITimeBasedDiscount.sol";


contract DestinationDeployer is Ownable, CCIPReceiver {

    address _staticDiscountImp;
    address _timeBasedDiscountImp;

    mapping(bytes32 => address) private staticDiscountAddresses;
    mapping(bytes32 => address) private timeBasedDiscountAddresses;


    event StaticDiscountCreated(string name, address discount);
    event TimeBasedDiscountCreated(string name, address discount);

	event Received(bytes sourceRouter, bytes32 messageId, uint64 sourceChainSelector);


    constructor(address router, address staticDiscount, address timeBasedDiscount) CCIPReceiver(router) {
        _staticDiscountImp = staticDiscount;
        _timeBasedDiscountImp = timeBasedDiscount;
    }


    function createStaticDiscount(string memory tokenName, string memory tokenSymbol, uint256[] memory tokenIds, string[] memory uris) public {

        // Create a static discount for a collection and setting up tokens metadata
        ERC1967Proxy discountProxy = new ERC1967Proxy(address(_staticDiscountImp), "");
        IStaticDiscount discount = IStaticDiscount(address(discountProxy));
        discount.initialize(tokenName, tokenSymbol, tokenIds, uris);

        // convert string name to bytes
        bytes32 name = getBytesString(tokenName);

        // store the discount address
        staticDiscountAddresses[name] = address(discount);

        // emit the name and the address of the discount contract
        emit StaticDiscountCreated(tokenName, address(discount));

    }


    function createTimeBasedDiscount(string calldata tokenName, string calldata tokenSymbol) public {

        // Create a time based discount for a collection 
        ERC1967Proxy discountProxy = new ERC1967Proxy(address(_staticDiscountImp), "");
        ITimeBasedDiscount discount = ITimeBasedDiscount(address(discountProxy));
        discount.initialize(tokenName, tokenSymbol);

        // convert string name to bytes
        bytes32 name = getBytesString(tokenName);

        // store the discount address
        timeBasedDiscountAddresses[name] = address(discount);

        // emit the name and the address of the discount contract
        emit TimeBasedDiscountCreated(tokenName, address(discount));

    }


    function mintStaticDiscount(string memory tokenName, address to, uint256 tokenId, uint256 amount) public {

        // convert string name to bytes
        bytes32 name = getBytesString(tokenName);
        address discountAddress = staticDiscountAddresses[name];

        require(discountAddress != address(0), "Discount not exists");

        // mint the static discount token
        IStaticDiscount(discountAddress).mint(to, tokenId, amount, "0x");
    }


    function mintTimeBasedDiscount(string memory tokenName, address to, uint256 tokenId, uint256 amount) public {

        // convert string name to bytes
        bytes32 name = getBytesString(tokenName);
        address discountAddress = timeBasedDiscountAddresses[name];

        require(discountAddress != address(0), "Discount not exists");

        // mint the time based discount token
        ITimeBasedDiscount(discountAddress).mint(to, tokenId, amount, "0x");
    }


    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (bool success, ) = address(this).call(message.data);
        //require(success);       
        emit Received(message.sender, message.messageId, message.sourceChainSelector);
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

}