// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;
pragma abicoder v2;

import "@iconfoundation/xcall-solidity-library/utils/RLPDecode.sol";
import "./Messages.sol";

library RLPDecodeStruct {
    using RLPDecode for RLPDecode.RLPItem;
    using RLPDecode for RLPDecode.Iterator;
    using RLPDecode for bytes;

    using RLPDecodeStruct for bytes;

    uint8 private constant LIST_SHORT_START = 0xc0;
    uint8 private constant LIST_LONG_START = 0xf7;

    function getMethod(
        bytes memory _rlp
    ) internal pure returns (string memory) {
        RLPDecode.RLPItem[] memory ls = _rlp.toRlpItem().toList();
        return string(ls[0].toBytes());
    }

    function decodeExecute(
        bytes memory _rlp
    ) internal pure returns (Messages.Execute memory) {
        RLPDecode.RLPItem[] memory ls = _rlp.toRlpItem().toList();
        return Messages.Execute(ls[1].toAddress(), ls[2].toBytes());
    }

    function decodeConfigureProtocols(
        bytes memory _rlp
    ) internal pure returns (Messages.ConfigureProtocols memory) {
        RLPDecode.RLPItem[] memory ls = _rlp.toRlpItem().toList();
        return
            Messages.ConfigureProtocols(
                toStringArray(ls[1]),
                toStringArray(ls[2])
            );
    }

    function toStringArray(
        RLPDecode.RLPItem memory item
    ) internal pure returns (string[] memory) {
        RLPDecode.RLPItem[] memory ls = item.toList();
        string[] memory protocols = new string[](ls.length);
        for (uint256 i = 0; i < ls.length; i++) {
            protocols[i] = string(ls[i].toBytes());
        }
        return protocols;
    }
}
