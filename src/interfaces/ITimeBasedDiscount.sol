// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;


interface ITimeBasedDiscount {

    function initialize(string calldata tokenName, string calldata tokenSymbol) external;

    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;

    function createToken(string calldata newUri, uint64 startAt, uint64 endAt, uint64 ratio) external;


}