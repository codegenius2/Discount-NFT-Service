# Discount On The Block Documentation

**Discount On The Block** is a decentralized discount management system designed to empower web3 projects by facilitating the creation, management, and claiming of various discounts. Leveraging the Ethereum blockchain, Chainlink's Cross-Chain Interoperability Protocol (CCIP), and innovative smart contract patterns, the architecture ensures a secure, flexible, and cross-chain-compatible environment.

<br ><br />
## High-Level Architecture

### 1. Smart Contracts

The **Smart Contracts** module serves as the system's backbone, responsible for discount-related functionalities, user interactions, and integration with external protocols.

**Main Functions:**

- **initializeDiscount:** Initializes a new discount with a specified name and type (TimeBased or StaticBased). This function sets the owner and type of the discount.

- **createStaticDiscount:** Creates a static-based discount with specified parameters such as token name, symbol, token IDs, URIs, and chain ID. It involves interacting with Chainlink for cross-chain communication and burning the discount upon utilization.

- **batchIncrementUsersBalances:** Increments the claim balances of multiple users for a specific discount. This function efficiently updates user balances in bulk.

- **claimStaticDiscount:** Allows users to claim a static-based discount, involving Chainlink automation and burning the discount upon utilization. Users must meet eligibility criteria to claim the discount.

- **createTimeBasedDiscount:** This function allows the owner of a discount to create a time-based discount contract on a specific Chain by sending a Chainlink CCIP message with the provided token information and expiration metadata.
  
- **claimTimeBasedDiscount:** Allows users to claim a time-based discount, involving Chainlink automation on the specific chain. (The user will be choosed the destination chain to claim and receive discount).

<br ><br />
### 2. OpenZeppelin Upgradeable Contracts

The **OpenZeppelin Upgradeable Contracts** module enhances the system's security and flexibility. It utilizes the UUPS pattern, enabling seamless upgrades without disrupting the system's functionality.

<br ><br />
### 3. Chainlink Integration

The **Chainlink Integration** module ensures seamless off-chain data communication and cross-chain interoperability through Chainlink's CCIP.

**Main Functions:**

- **buildCCIPMessage:** Constructs a CCIP message with specified data and chain ID. This function is essential for preparing messages for cross-chain communication.

- **sendCCIPMessage:** Sends a CCIP message to the CCIP Router contract for cross-chain communication. It involves verifying the message sender and ensuring sufficient value for the communication.

- **getCCIPMessageFee:** Calculates the fee required for sending a CCIP message. This function determines the cost associated with cross-chain communication.

<br ><br />
### 4. UUPS Pattern

The **UUPS Pattern** module facilitates the creation and management of new discounts, enhancing the system's upgradability and flexibility.

<br ><br />
### 5. ERC1155 NFTs

The **ERC1155 NFTs** module represents each discount as a unique and tradeable token, adding a dynamic layer to the discount ecosystem. Users can own and interact with their discounts as NFTs.

<br ><br />
### 6. Automated Expiration with Chainlink

The **Automated Expiration with Chainlink** module manages the automatic expiration of discounts using Chainlink automation.
