// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;
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

    function decodeCrossTransfer(
        bytes memory _rlp
    ) internal pure returns (Messages.XCrossTransfer memory) {
        RLPDecode.RLPItem[] memory ls = _rlp.toRlpItem().toList();
        return
            Messages.XCrossTransfer(
                string(ls[1].toBytes()),
                string(ls[2].toBytes()),
                ls[3].toUint(),
                ls[4].toBytes()
            );
    }

    function decodeCrossTransferRevert(
        bytes memory _rlp
    ) internal pure returns (Messages.XCrossTransferRevert memory) {
        RLPDecode.RLPItem[] memory ls = _rlp.toRlpItem().toList();
        return
            Messages.XCrossTransferRevert(
                ls[1].toAddress(),
                ls[2].toUint()
            );
    }
}
