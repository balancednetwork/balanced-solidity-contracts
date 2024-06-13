// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;
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

    function encodeCrossTransfer(
        Messages.XCrossTransfer memory message
    ) internal pure returns (bytes memory) {
        bytes memory _rlp = abi.encodePacked(
            Messages.CROSS_TRANSFER.encodeString(),
            message.from.encodeString(),
            message.to.encodeString(),
            message.value.encodeUint(),
            message.data.encodeBytes()
        );
        return _rlp.encodeList();
    }

    function encodeCrossTransferRevert(
        Messages.XCrossTransferRevert memory message
    ) internal pure returns (bytes memory) {
        bytes memory _rlp = abi.encodePacked(
            Messages.CROSS_TRANSFER_REVERT.encodeString(),
            message.to.encodeAddress(),
            message.value.encodeUint()
        );
        return _rlp.encodeList();
    }
}
