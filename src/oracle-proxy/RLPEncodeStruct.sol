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

    function encodeUpdatePriceData(
        Messages.UpdatePriceData memory data
    ) internal pure returns (bytes memory) {
        bytes memory _rlp = abi.encodePacked(
            Messages.UPDATE_PRICE_DATA.encodeString(),
            data.symbol.encodeString(),
            data.priceInUSD.encodeUint(),
            data.timestampMicroSeconds.encodeUint()
        );
        return _rlp.encodeList();
    }
}
