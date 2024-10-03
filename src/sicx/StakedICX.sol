// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@balanced/contracts/lib/spoke-token/SpokeToken.sol";

contract StakedICX is SpokeToken {
    constructor() {
        _disableInitializers();
    }
    string private constant NAME = "Staked ICX";
    string private constant SYMBOL = "SICX";
    uint8 private constant DECIMALS = 12;

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

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
