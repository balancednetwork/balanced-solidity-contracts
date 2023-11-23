// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;
pragma abicoder v2;

import "@iconfoundation/xcall-solidity-library/utils/RLPEncode.sol";
import "./Messages.sol";

library RLPEncodeStruct {
    using RLPEncode for bytes;
    using RLPEncode for string;
    using RLPEncode for uint256;
    using RLPEncode for int256;
    using RLPEncode for address;
    using RLPEncode for bool;

    function encodeExecute(
        Messages.Execute memory message
    ) internal pure returns (bytes memory) {
        bytes memory _rlp = abi.encodePacked(
            Messages.EXECUTE_NAME.encodeString(),
            message.contractAddress.encodeAddress(),
            message.data.encodeBytes()
        );
        return _rlp.encodeList();
    }

    function encodeConfigureProtocols(
        Messages.ConfigureProtocols memory message
    ) internal pure returns (bytes memory) {
        bytes memory temp;

        bytes memory _sources;
        for (uint256 i = 0; i < message.sources.length; i++) {
            temp = abi.encodePacked(message.sources[i].encodeString());
            _sources = abi.encodePacked(_sources, temp);
        }

        bytes memory _destinations;
        for (uint256 i = 0; i < message.destinations.length; i++) {
            temp = abi.encodePacked(message.destinations[i].encodeString());
            _destinations = abi.encodePacked(_destinations, temp);
        }

        bytes memory _rlp = abi.encodePacked(
            Messages.CONFIGURE_PROTOCOLS_NAME.encodeString(),
            _sources.encodeList(),
            _destinations.encodeList()
        );
        return _rlp.encodeList();
    }
}
