// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import { IRouterClient } from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable@4.9.1/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable@4.9.1/access/OwnableUpgradeable.sol";

/**
 * @title SourceManager
 * @dev Manages configurations and interactions with the Chainlink CCIP (Cross-Chain Interoperability Protocol) router.
 * @dev This contract provides essential functionality for cross-chain communication and routing on the source chain.
 */
contract SourceManager is Initializable, OwnableUpgradeable {

    struct NetworkConf {
        address destination;
        uint64 chainSelector;
    }

    // the address of the router for source chain
    address internal ccipRouter;

    // Mapping to track allowed chains for CCIP messages.
    mapping(uint256 => bool) internal allowedChains;

    // Mapping to store network configurations for each supported chain.
    mapping(uint256 => NetworkConf) internal chainIdToConf;
    
    // Event for successful CCIP send message.
    event MessageSent(bytes32 messageId);


    /**
     * @dev Initializes the SourceManager contract with the specified CCIP router address.
     * @param _ccipRouter The address of the Chainlink CCIP router.
     */
    function __SourceManager_init(address _ccipRouter) onlyInitializing internal {

        ccipRouter = _ccipRouter;
    }


    /**
     * @dev Sets up network configurations for supported chains.
     * @param chainIds An array of chain IDs to configure.
     * @param chainSelectors An array of chain selectors corresponding to each chain ID.
     * @param destinations An array of destination addresses for each chain ID.
     */
    function setUpNetworkConfig(uint256[] calldata chainIds, uint64[] calldata chainSelectors, address[] calldata destinations) public onlyOwner {
        
        uint256 length = chainIds.length;

        // check the validation of input arrays
        require(length == chainSelectors.length && length == destinations.length, "Invalid arrays length");

        NetworkConf memory network;

        for(uint256 index; index < length; index++) {

            uint256 chainId = chainIds[index];

            // add chainId to allow list
            allowedChains[chainId] = true;

            // create and store network conf
            network = NetworkConf(
                destinations[index],
                chainSelectors[index]
            );
            chainIdToConf[chainId] = network;
        }
    }


    /**
     * @dev Builds a CCIP message with the specified data for a given chain ID.
     * @param data The message data.
     * @param chainId The chain ID for which the message is intended.
     * @return A CCIP message structure.
     */
    function _buildCCIPMessage(bytes memory data, uint256 chainId) internal view returns (Client.EVM2AnyMessage memory) {
        
        // retrieve the address of destination contract based on chain id
        address receiver = chainIdToConf[chainId].destination;

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 4_000_000})
            ),
            feeToken: address(0)
        });

        return message;
    }


    /**
     * @dev Sends a CCIP message to the specified chain using the CCIP router.
     * @param message The CCIP message to be sent.
     * @param chainId The chain ID to which the message should be sent.
     */
    function sendCCIPMessage(Client.EVM2AnyMessage memory message, uint256 chainId) internal {

        // get the fee ccip message based on destination chain
        uint256 fee = _getCCIPMessageFee(message, chainId);

        // retrive the destination chain selector id
        uint64 chainSelector = chainIdToConf[chainId].chainSelector;

        // send the specified message to the destionation contract
        bytes32 messageId = IRouterClient(ccipRouter).ccipSend{value: fee}(
            chainSelector,
            message
        );
        
        emit MessageSent(messageId);
    }


    /**
     * @dev Retrieves the fee for sending a CCIP message to a specified chain.
     * @param message The CCIP message for which the fee is calculated.
     * @param chainId The chain ID to which the message should be sent.
     * @return The calculated fee amount.
     */
    function _getCCIPMessageFee(Client.EVM2AnyMessage memory message, uint256 chainId) internal view returns(uint256) {
        
        uint64 chainSelector = chainIdToConf[chainId].chainSelector;

        uint256 fee = IRouterClient(ccipRouter).getFee(
            chainSelector,
            message
        );

        return fee;
    }

    
}