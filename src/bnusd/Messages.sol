// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

/**
 * @notice List of ALL Struct being used to Encode and Decode RLP Messages
 */
library Messages {
    string constant CROSS_TRANSFER = "xCrossTransfer";
    struct XCrossTransfer {
        string from;
        string to;
        uint value;
        bytes data;
    }

    string constant CROSS_TRANSFER_REVERT = "xCrossTransferRevert";
    struct XCrossTransferRevert {
        address to;
        uint value;
    }
}
