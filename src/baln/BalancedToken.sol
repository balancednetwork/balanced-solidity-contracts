// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@balanced/contracts/lib/spoke-token/SpokeToken.sol";

contract BalancedToken is SpokeToken {
    constructor() {
        _disableInitializers();
    }
    string private constant NAME = "Balanced Token";
    string private constant SYMBOL = "BALN";

    function initialize_token(
        address _xCall,
        string memory _iconTokenAddress,
        address _xCallManager
    ) public initializer {
        SpokeToken.initialize(
            NAME,
            SYMBOL,
            _xCall,
            _iconTokenAddress,
            _xCallManager
        );
    }
}
