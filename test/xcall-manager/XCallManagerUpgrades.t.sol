// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@balanced/contracts/asset-manager/AssetManager.sol" ;
import "@balanced/contracts/xcall-manager/XCallManager.sol" as Manager;
import "@balanced/contracts/xcall-manager/Messages.sol" as ManagerMessages;
import "@balanced/contracts/xcall-manager/RLPEncodeStruct.sol" as ManagerEncode;
import "@balanced/contracts/lib/interfaces/IXCallManager.sol";

import "@iconfoundation/xcall-solidity-library/interfaces/ICallService.sol";
import "@iconfoundation/xcall-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/xcall-solidity-library/utils/Strings.sol";
import "@iconfoundation/xcall-solidity-library/utils/ParseAddress.sol";

contract XCallManagerTest is Test {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using ManagerEncode.RLPEncodeStruct for ManagerMessages.Messages.Execute;

    address public user = address(0x11);
    address public owner = address(0x12);
    address public admin = address(0x13);
    Manager.XCallManager public xCallManager;
    AssetManager public assetManager;
    ICallService public xCall;

    string public constant nid = "0x1.eth";
    string public constant ICON_GOVERNANCE = "0x1.icon/cx1";
    string[] defaultSources = ["0x05", "0x06"];
    string[] defaultDestinations = ["cx2", "cx3"];

    string[] newSources;
    string[] newDestinations;
    string[] deliverySources;

    function setUp() public {
        xCall = ICallService(address(0x01));
        vm.mockCall(
            address(xCall),
            abi.encodeWithSelector(xCall.getNetworkAddress.selector),
            abi.encode(nid.networkAddress(address(xCall).toString()))
        );
        address xcallManagerAddress = address(new Manager.XCallManager());
        vm.startPrank(owner);
        xCallManager = Manager.XCallManager(address(new ERC1967Proxy(xcallManagerAddress,  abi.encodeWithSelector(
            xCallManager.initialize.selector,
            address(xCall),
            ICON_GOVERNANCE,
            address(admin),
            defaultSources,
            defaultDestinations
        ))));

        address assetManagerAddress = address(new AssetManager());
        assetManager = AssetManager(address(new ERC1967Proxy(assetManagerAddress,  abi.encodeWithSelector(
            assetManager.initialize.selector,
            address(xCall),
            "iconAssetManager",
            address(xCallManager)
        ))));
        vm.stopPrank();
    }

    string[] sources = ["0x759211c693728f731e1E06B7CE9Ed7b50359CE03"];
    string[] destinations = ["cx2e230f2f91f7fe0f0b9c6fe1ce8dbba9f74f961a"];
    function testprint() public {
        // bytes memory param = abi.encodeWithSelector(
        //     xCallManager.initialize.selector,
        //     address(0xC938B1B7C20D080Ca3B67eebBfb66a75Fb3C4995),
        //     "0x2.icon/cxdb3d3e2717d4896b336874015a4b23871e62fb6b",
        //     address(0x601020c5797Cdd34f64476b9bf887a353150Cb9a),
        //     sources,
        //     destinations
        // );
        // console.logBytes(param);
        bytes memory param = abi.encodeWithSelector(
            assetManager.initialize.selector,
            address(0xC938B1B7C20D080Ca3B67eebBfb66a75Fb3C4995),
            "0x2.icon/cxe9d69372f6233673a6ebe07862e12af4c2dca632",
            address(0x0d85A1B9f7982091A5C8bD56Af81fB4d2f0D50d5)
        );
        console.logBytes(param);
    }
// 0x3bb8b048000000000000000000000000c938b1b7c20d080ca3b67eebbfb66a75fb3c499500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000601020c5797cdd34f64476b9bf887a353150cb9a000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000000333078322e69636f6e2f6378646233643365323731376434383936623333363837343031356134623233383731653632666236620000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002a3078373539323131633639333732386637333165314530364237434539456437623530333539434530330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002a63783265323330663266393166376665306630623963366665316365386462626139663734663936316100000000000000000000000000000000000000000000
    function testUpgradeSelf() public {
        // Arrange
        vm.prank(owner);
        xCallManager.transferOwnership(address(xCallManager));
        Manager.XCallManager newXCallManager = new Manager.XCallManager();

        ManagerMessages.Messages.Execute memory upgradeMessage = ManagerMessages.Messages.Execute(
            address(xCallManager),
            abi.encodeWithSelector(
                xCallManager.upgradeToAndCall.selector,
                address(newXCallManager),
                ""
            )
        );

        // Assert
        vm.expectCall(
            address(xCallManager),
            abi.encodeWithSelector(
                xCallManager.upgradeToAndCall.selector,
                address(newXCallManager),
                ""
            )
        );

        // Act
        vm.prank(address(xCall));
        xCallManager.handleCallMessage(
            ICON_GOVERNANCE,
            upgradeMessage.encodeExecute(),
            defaultSources
        );
        assertEq(xCallManager.getImplementation(), address(newXCallManager));
    }

    function testUpgradeExternalContract() public {
        // Arrange
        vm.prank(owner);
        assetManager.transferOwnership(address(xCallManager));
        AssetManager newAssetManager = new AssetManager();

        ManagerMessages.Messages.Execute memory upgradeMessage = ManagerMessages.Messages.Execute(
            address(assetManager),
            abi.encodeWithSelector(
                assetManager.upgradeToAndCall.selector,
                address(newAssetManager),
                ""
            )
        );
        // Assert
        vm.expectCall(
            address(assetManager),
            abi.encodeWithSelector(
                assetManager.upgradeToAndCall.selector,
                address(newAssetManager),
                ""
            )
        );

        // Act
        vm.prank(address(xCall));
        xCallManager.handleCallMessage(
            ICON_GOVERNANCE,
            upgradeMessage.encodeExecute(),
            defaultSources
        );
        assertEq(assetManager.getImplementation(), address(newAssetManager));
    }

}
