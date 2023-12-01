// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IStaticDiscount {

    function pause() external;
    
    function unpause() external;

    function initialize(string calldata tokenName, string calldata tokenSymbol, uint256[] calldata tokenIds, string[] calldata uris) external;

    function setBatchURI(uint256[] calldata tokenIds, string[] calldata uris) external;

    function mint(address account, uint256 id, uint256 amount, bytes calldata data) external;

    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
   
}