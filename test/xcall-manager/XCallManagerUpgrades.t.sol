// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@balanced/contracts/asset-manager/AssetManager.sol";
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
        xCallManager = Manager.XCallManager(
            address(
                new ERC1967Proxy(
                    xcallManagerAddress,
                    abi.encodeWithSelector(
                        xCallManager.initialize.selector,
                        address(xCall),
                        ICON_GOVERNANCE,
                        address(admin),
                        defaultSources,
                        defaultDestinations
                    )
                )
            )
        );

        address assetManagerAddress = address(new AssetManager());
        assetManager = AssetManager(
            address(
                new ERC1967Proxy(
                    assetManagerAddress,
                    abi.encodeWithSelector(
                        assetManager.initialize.selector,
                        address(xCall),
                        "iconAssetManager",
                        address(xCallManager)
                    )
                )
            )
        );
        vm.stopPrank();
    }

    function testUpgradeSelf() public {
        // Arrange
        vm.prank(owner);
        xCallManager.transferOwnership(address(xCallManager));
        Manager.XCallManager newXCallManager = new Manager.XCallManager();

        ManagerMessages.Messages.Execute memory upgradeMessage = ManagerMessages
            .Messages
            .Execute(
                address(xCallManager),
                abi.encodeWithSelector(
                    xCallManager.upgradeToAndCall.selector,
                    address(newXCallManager),
                    ""
                )
            );

        vm.prank(admin);
        xCallManager.whitelistAction(upgradeMessage.encodeExecute());

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

        ManagerMessages.Messages.Execute memory upgradeMessage = ManagerMessages
            .Messages
            .Execute(
                address(assetManager),
                abi.encodeWithSelector(
                    assetManager.upgradeToAndCall.selector,
                    address(newAssetManager),
                    ""
                )
            );
        vm.prank(admin);
        xCallManager.whitelistAction(upgradeMessage.encodeExecute());

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
