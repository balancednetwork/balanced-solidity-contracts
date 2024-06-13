// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

/**
 * @notice List of ALL Struct being used to Encode and Decode RLP Messages
 */
library Messages {
    string constant DEPOSIT_NAME = "Deposit";
    struct Deposit {
        string tokenAddress;
        string from;
        string to;
        uint amount;
        bytes data;
    }

    string constant DEPOSIT_REVERT_NAME = "DepositRevert";
    struct DepositRevert {
        address tokenAddress;
        uint amount;
        address to;
    }

    string constant WITHDRAW_TO_NAME = "WithdrawTo";
    struct WithdrawTo {
        string tokenAddress;
        string to;
        uint amount;
    }

    string constant WITHDRAW_NATIVE_TO_NAME = "WithdrawNativeTo";
}
