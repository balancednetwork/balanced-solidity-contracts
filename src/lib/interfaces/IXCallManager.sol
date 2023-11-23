// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

interface IXCallManager {
    struct Protocols {
        string[] sources;
        string[] destinations;
    }

    function getProtocols() external view returns (Protocols memory protocols);

    function verifyProtocols(
        string[] calldata protocols
    ) external view returns (bool);
}
