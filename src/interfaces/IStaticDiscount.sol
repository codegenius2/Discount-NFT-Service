// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IStaticDiscount {

    function pause() external;
    
    function unpause() external;

    function initialize(string memory tokenName, string memory tokenSymbol, uint256[] memory tokenIds, string[] memory uris) external;

    function setBatchURI(uint256[] memory tokenIds, string[] memory uris) external;

    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;
   
}