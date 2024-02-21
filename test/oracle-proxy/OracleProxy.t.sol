// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import "forge-std/interfaces/IERC4626.sol";
import "@balanced/contracts/oracle-proxy/OracleProxy.sol";
import "@balanced/contracts/oracle-proxy/Messages.sol";
import "@balanced/contracts/lib/interfaces/IXCallManager.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@iconfoundation/xcall-solidity-library/interfaces/ICallService.sol";
import "@iconfoundation/xcall-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/xcall-solidity-library/utils/Strings.sol";
import "@iconfoundation/xcall-solidity-library/utils/ParseAddress.sol";

contract OracleProxyTest is Test {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.UpdatePriceData;

    address public user = address(0x1234);
    address public owner = address(0x2345);

    OracleProxy public oracelProxy;
    IXCallManager public xCallManager;
    ICallService public xCall;
    IERC4626 public creditVault;
    IERC20 public asset;
    string public constant BALANCED_ORACLE = "0x1.icon/cx1";
    string[] defaultSources = ["0x05", "0x06"];
    string[] defaultDestinations = ["cx2", "cx3"];

    function setUp() public {
        xCall = ICallService(address(0x01));
        xCallManager = IXCallManager(address(0x02));
        creditVault = IERC4626(address(0x03));
        asset = IERC20(address(0x04));

        vm.mockCall(
            address(xCallManager),
            abi.encodeWithSelector(xCallManager.getProtocols.selector),
            abi.encode(
                IXCallManager.Protocols(defaultSources, defaultDestinations)
            )
        );


        oracelProxy = new OracleProxy();
        address oracelProxyAddress = address(oracelProxy);
        vm.prank(owner);
        oracelProxy = OracleProxy(address(new ERC1967Proxy(oracelProxyAddress,  abi.encodeWithSelector(
            oracelProxy.initialize.selector,
            address(xCall),
            BALANCED_ORACLE,
            address(xCallManager)
        ))));
    }

    function testUpdatePrice() public {
        // Arrange
        uint rate = 10**6 + 10**5;
        uint expectedRate = 10**18 + 10**17;
        uint fee = 100;

        vm.mockCall(address(creditVault), abi.encodeWithSelector(creditVault.symbol.selector), abi.encode("hyUSDC"));
        vm.mockCall(address(creditVault), abi.encodeWithSelector(creditVault.decimals.selector), abi.encode(18));
        vm.mockCall(address(creditVault), abi.encodeWithSelector(creditVault.asset.selector), abi.encode(address(asset)));
        vm.mockCall(address(asset), abi.encodeWithSelector(asset.decimals.selector), abi.encode(6));
        vm.mockCall(address(creditVault), abi.encodeWithSelector(creditVault.convertToAssets.selector, 10**18), abi.encode(rate));
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
                "",
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        vm.prank(owner);
        oracelProxy.addCreditVault(address(creditVault));
        oracelProxy.updateCreditVaultPrice{value: fee}(address(creditVault));
    }

    function testRemoveVault() public {
        // Arrange
        uint rate = 10**6 + 10**5;
        uint expectedRate = 10**18 + 10**17;
        uint fee = 100;

        vm.mockCall(address(creditVault), abi.encodeWithSelector(creditVault.symbol.selector), abi.encode("hyUSDC"));
        vm.mockCall(address(creditVault), abi.encodeWithSelector(creditVault.decimals.selector), abi.encode(18));
        vm.mockCall(address(creditVault), abi.encodeWithSelector(creditVault.asset.selector), abi.encode(address(asset)));
        vm.mockCall(address(asset), abi.encodeWithSelector(creditVault.decimals.selector), abi.encode(6));
        vm.mockCall(address(creditVault), abi.encodeWithSelector(creditVault.convertToAssets.selector, 10**18), abi.encode(rate));

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
                "",
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        vm.prank(owner);
        oracelProxy.addCreditVault(address(creditVault));
        oracelProxy.updateCreditVaultPrice{value: fee}(address(creditVault));
        vm.prank(owner);
        oracelProxy.removeCreditVault(address(creditVault));

         // Assert
        vm.expectRevert("Credit vault not whitelisted");

        // Act
        oracelProxy.updateCreditVaultPrice(address(creditVault));
    }

    function testUpdatePrice_nonConfiguredVault() public {
        // Assert
        vm.expectRevert("Credit vault not whitelisted");

        // Act
        oracelProxy.updateCreditVaultPrice(address(creditVault));
    }


   function testAddRemoveVault_OwnerOnly() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        oracelProxy.addCreditVault(address(creditVault));

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        oracelProxy.removeCreditVault(address(creditVault));
    }


    function testUpgrade_notOwner() public {
        // Arrange
        address oracelProxyAddress = address(new OracleProxy());
        vm.prank(user);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        oracelProxy.upgradeToAndCall(oracelProxyAddress, "");
    }

    function testUpgrade() public {
        // Arrange
        address oracelProxyAddress = address(new OracleProxy());
        vm.prank(owner);

        // Act
        oracelProxy.upgradeToAndCall(oracelProxyAddress, "");

        // Assert
        assertEq(oracelProxyAddress, oracelProxy.getImplementation());
    }
}