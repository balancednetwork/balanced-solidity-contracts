// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

/**
 * @notice List of ALL Struct being used to Encode and Decode RLP Messages
 */
library Messages {
    string constant EXECUTE_NAME = "Execute";
    struct Execute {
        address contractAddress;
        bytes data;
    }

    string constant CONFIGURE_PROTOCOLS_NAME = "ConfigureProtocols";
    struct ConfigureProtocols {
        string[] sources;
        string[] destinations;
    }
}
