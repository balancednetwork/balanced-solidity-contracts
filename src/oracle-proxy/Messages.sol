// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

/**
 * @notice List of ALL Struct being used to Encode and Decode RLP Messages
 */
library Messages {
    string constant UPDATE_PRICE_DATA = "updatePriceData";

    struct UpdatePriceData {
        string symbol;
        uint priceInUSD;
        uint timestampMicroSeconds;
    }
}
