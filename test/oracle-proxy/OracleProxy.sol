// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@balanced/contracts/oracle-proxy/OracleProxy.sol";
import "@balanced/contracts/oracle-proxy/Messages.sol";
import "@balanced/contracts/lib/interfaces/IXCallManager.sol";

import "@iconfoundation/xcall-solidity-library/interfaces/ICallService.sol";
import "@iconfoundation/xcall-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/xcall-solidity-library/utils/Strings.sol";
import "@iconfoundation/xcall-solidity-library/utils/ParseAddress.sol";

contract AssetManagerTest is Test {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.UpdatePriceData;

    address public user = address(0x1234);
    OracleProxy public oracelProxy;
    IXCallManager public xCallManager;
    ICallService public xCall;
    IPassivePool public passivePool;
    string public constant BALANCED_ORACLE = "0x1.icon/cx1";
    string[] defaultSources = ["0x05", "0x06"];
    string[] defaultDestinations = ["cx2", "cx3"];

    function setUp() public {
        xCall = ICallService(address(0x01));
        xCallManager = IXCallManager(address(0x02));
        oracelProxy = new OracleProxy();
        vm.mockCall(
            address(xCallManager),
            abi.encodeWithSelector(xCallManager.getProtocols.selector),
            abi.encode(
                IXCallManager.Protocols(defaultSources, defaultDestinations)
            )
        );

        oracelProxy.initialize(
            address(xCall),
            BALANCED_ORACLE,
            address(xCallManager)
        );
    }

    function testUpdatePrice() public {
        // Arrange
        uint rate = 10**6 + 10**5;
        uint expectedRate = 10**18 + 10**17;
        uint fee = 100;
        vm.mockCall(address(passivePool), abi.encodeWithSelector(passivePool.rate.selector), abi.encode(rate));
        vm.mockCall(
                address(xCall),
                fee,
                abi.encodeWithSelector(xCall.sendCallMessage.selector),
                abi.encode(0)
            );

        Messages.UpdatePriceData memory expectedMessage = Messages.UpdatePriceData(
            "hyUSDC",
            expectedRate,
            block.timestamp*1000000
        );

        // Assert
        vm.expectCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(
                xCall.sendCallMessage.selector,
                BALANCED_ORACLE,
                expectedMessage.encodeUpdatePriceData(),
                "0x",
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        oracelProxy.updateHiYeildPrice{value: fee}();
    }
}