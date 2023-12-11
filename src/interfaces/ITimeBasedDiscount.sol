// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;


interface ITimeBasedDiscount {

    function initialize(string memory tokenName, string memory tokenSymbol, string memory _expireMetadata) external;

    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;

    function createToken(string memory newUri, uint64 startAt, uint64 endAt, uint64 ratio) external;


}