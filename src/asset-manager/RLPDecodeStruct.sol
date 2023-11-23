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

    function decodeDeposit(
        bytes memory _rlp
    ) internal pure returns (Messages.Deposit memory) {
        RLPDecode.RLPItem[] memory ls = _rlp.toRlpItem().toList();
        return
            Messages.Deposit(
                string(ls[1].toBytes()),
                string(ls[2].toBytes()),
                string(ls[3].toBytes()),
                ls[4].toUint(),
                ls[5].toBytes()
            );
    }

    function decodeDepositRevert(
        bytes memory _rlp
    ) internal pure returns (Messages.DepositRevert memory) {
        RLPDecode.RLPItem[] memory ls = _rlp.toRlpItem().toList();
        return
            Messages.DepositRevert(
                ls[1].toAddress(),
                ls[2].toUint(),
                ls[3].toAddress()
            );
    }

    function decodeWithdrawTo(
        bytes memory _rlp
    ) internal pure returns (Messages.WithdrawTo memory) {
        RLPDecode.RLPItem[] memory ls = _rlp.toRlpItem().toList();
        return
            Messages.WithdrawTo(
                string(ls[1].toBytes()),
                string(ls[2].toBytes()),
                ls[3].toUint()
            );
    }
}
