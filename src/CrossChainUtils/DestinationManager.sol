// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts@4.9.1/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts@4.9.1/access/Ownable.sol";
import {IStaticDiscount} from "../interfaces/IStaticDiscount.sol";
import {ITimeBasedDiscount} from "../interfaces/ITimeBasedDiscount.sol";


contract DestinationManager is Ownable, CCIPReceiver {

    address _staticDiscountImp;
    address _timeBasedDiscountImp;


    event StaticDiscountCreated(string name, address discount);
    event TimeBasedDiscountCreated(string name, address discount);


    constructor(address router, address staticDiscount, address timeBasedDiscount) CCIPReceiver(router) {
        _staticDiscountImp = staticDiscount;
        _timeBasedDiscountImp = timeBasedDiscount;
    }


    function createStaticDiscount(string calldata tokenName, string calldata tokenSymbol, uint256[] calldata tokenIds, string[] calldata uris) public onlyOwner {

        // Create a static discount for a collection and setting up tokens metadata
        ERC1967Proxy discountProxy = new ERC1967Proxy(address(_staticDiscountImp), "");
        IStaticDiscount discount = IStaticDiscount(address(discountProxy));
        discount.initialize(tokenName, tokenSymbol, tokenIds, uris);

        // emit the name and the address of the discount contract
        emit StaticDiscountCreated(tokenName, address(discount));

    }


    function createTimeBasedDiscount(string calldata tokenName, string calldata tokenSymbol) public onlyOwner {

        // Create a time based discount for a collection 
        ERC1967Proxy discountProxy = new ERC1967Proxy(address(_staticDiscountImp), "");
        ITimeBasedDiscount discount = ITimeBasedDiscount(address(discountProxy));
        discount.initialize(tokenName, tokenSymbol);

        // emit the name and the address of the discount contract
        emit TimeBasedDiscountCreated(tokenName, address(discount));

    }


    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (bool success, ) = address(this).call(message.data);
        require(success);        
    }
}