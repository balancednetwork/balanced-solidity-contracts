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

    function encodeDeposit(
        Messages.Deposit memory message
    ) internal pure returns (bytes memory) {
        bytes memory _rlp = abi.encodePacked(
            Messages.DEPOSIT_NAME.encodeString(),
            message.tokenAddress.encodeString(),
            message.from.encodeString(),
            message.to.encodeString(),
            message.amount.encodeUint(),
            message.data.encodeBytes()
        );
        return _rlp.encodeList();
    }

    function encodeDepositRevert(
        Messages.DepositRevert memory message
    ) internal pure returns (bytes memory) {
        bytes memory _rlp = abi.encodePacked(
            Messages.DEPOSIT_REVERT_NAME.encodeString(),
            message.tokenAddress.encodeAddress(),
            message.amount.encodeUint(),
            message.to.encodeAddress()
        );
        return _rlp.encodeList();
    }

    function encodeWithdrawTo(
        Messages.WithdrawTo memory message
    ) internal pure returns (bytes memory) {
        bytes memory _rlp = abi.encodePacked(
            Messages.WITHDRAW_TO_NAME.encodeString(),
            message.tokenAddress.encodeString(),
            message.to.encodeString(),
            message.amount.encodeUint()
        );
        return _rlp.encodeList();
    }

    function encodeWithdrawNativeTo(
        Messages.WithdrawTo memory message
    ) internal pure returns (bytes memory) {
        bytes memory _rlp = abi.encodePacked(
            Messages.WITHDRAW_NATIVE_TO_NAME.encodeString(),
            message.tokenAddress.encodeString(),
            message.to.encodeString(),
            message.amount.encodeUint()
        );
        return _rlp.encodeList();
    }
}
