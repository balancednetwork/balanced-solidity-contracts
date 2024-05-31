// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@balanced/contracts/xcall-manager/XCallManager.sol";
import "@balanced/contracts/xcall-manager/Messages.sol";
import "@balanced/contracts/lib/interfaces/IXCallManager.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@iconfoundation/xcall-solidity-library/interfaces/ICallService.sol";
import "@iconfoundation/xcall-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/xcall-solidity-library/utils/Strings.sol";
import "@iconfoundation/xcall-solidity-library/utils/ParseAddress.sol";

contract XCallManagerTest is Test {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.Execute;
    using RLPEncodeStruct for Messages.ConfigureProtocols;

    address public user = address(0x11);
    address public admin = address(0x12);
    address public owner = address(0x13);
    XCallManager public xCallManager;
    ICallService public xCall;
    IERC20 public token;
    string public constant nid = "0x1.eth";
    string public constant ICON_GOVERNANCE = "0x1.icon/cx1";
    string[] defaultSources = ["0x05", "0x06"];
    string[] defaultDestinations = ["cx2", "cx3"];

    string[] newSources;
    string[] newDestinations;
    string[] deliverySources;

    function setUp() public {
        xCall = ICallService(address(0x01));
        token = IERC20(address(0x3));
        vm.mockCall(
            address(xCall),
            abi.encodeWithSelector(xCall.getNetworkAddress.selector),
            abi.encode(nid.networkAddress(address(xCall).toString()))
        );

        xCallManager = new XCallManager();
        address xCallManagerAddress = address(xCallManager);
        vm.prank(owner);
        xCallManager = XCallManager(
            address(
                new ERC1967Proxy(
                    xCallManagerAddress,
                    abi.encodeWithSelector(
                        xCallManager.initialize.selector,
                        address(xCall),
                        ICON_GOVERNANCE,
                        admin,
                        defaultSources,
                        defaultDestinations
                    )
                )
            )
        );
    }

    function testGetProtocols() public view {
        // Act
        IXCallManager.Protocols memory protocols = xCallManager.getProtocols();

        // Assert
        assert(
            keccak256(abi.encode(protocols)) ==
                keccak256(
                    abi.encode(
                        IXCallManager.Protocols(
                            defaultSources,
                            defaultDestinations
                        )
                    )
                )
        );
    }

    function testVerifyProtocols() public {
        assertTrue(xCallManager.verifyProtocols(defaultSources));
        assertFalse(xCallManager.verifyProtocols(defaultDestinations));

        string[] memory empty;
        assertFalse(xCallManager.verifyProtocols(empty));
        deliverySources = [defaultSources[0], defaultSources[0]];
        assertFalse(xCallManager.verifyProtocols(deliverySources));
        deliverySources = [defaultSources[0]];
        assertFalse(xCallManager.verifyProtocols(deliverySources));
    }

    function testSetAdmin_nonAdmin() public {
        // Arrange
        vm.prank(user);

        // Assert
        vm.expectRevert("onlyAdmin");

        // Act
        xCallManager.setAdmin(user);
    }

    function testSetAdmin() public {
        // Arrange
        vm.prank(admin);

        // Act
        xCallManager.setAdmin(user);

        // Assert
        assertEq(xCallManager.admin(), user);
    }

    function testHandleCallMessage() public {
        // Arrange
        vm.prank(user);

        // Assert
        vm.expectRevert("onlyCallService");

        // Act
        xCallManager.handleCallMessage("", "", defaultSources);
    }

    function testHandleCallMessage_OnlyGovernance() public {
        // Arrange
        vm.prank(address(xCall));

        // Assert
        vm.expectRevert("Only ICON Balanced governance is allowed");

        // Act
        xCallManager.handleCallMessage("", "", defaultSources);
    }

    function testHandleCallMessage_InvalidProtocol() public {
        // Arrange
        vm.prank(address(xCall));

        // Assert
        vm.expectRevert("Protocol Mismatch");

        Messages.Execute memory executeMesage = Messages.Execute(
            address(token),
            ""
        );

        // Act
        xCallManager.handleCallMessage(
            ICON_GOVERNANCE,
            executeMesage.encodeExecute(),
            defaultDestinations
        );
    }

    function testExecute() public {
        // Arrange
        uint amount = 100;
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transfer.selector),
            abi.encode(0)
        );
        Messages.Execute memory executeMessage = Messages.Execute(
            address(token),
            abi.encodeWithSelector(
                token.transfer.selector,
                address(user),
                amount
            )
        );

        vm.prank(admin);
        xCallManager.whitelistAction(executeMessage.encodeExecute());

        // Assert
        vm.expectCall(
            address(token),
            abi.encodeWithSelector(
                token.transfer.selector,
                address(user),
                amount
            )
        );

        // Act
        vm.prank(address(xCall));
        xCallManager.handleCallMessage(
            ICON_GOVERNANCE,
            executeMessage.encodeExecute(),
            defaultSources
        );
    }

    function testConfigureProtocols() public {
        // Arrange
        newSources = ["0x045", "0x046"];
        newDestinations = ["cx35", "cx36"];

        Messages.ConfigureProtocols memory configureProtocolsMessage = Messages
            .ConfigureProtocols(newSources, newDestinations);
        vm.prank(admin);
        xCallManager.whitelistAction(
            configureProtocolsMessage.encodeConfigureProtocols()
        );

        // Act
        vm.prank(address(xCall));
        xCallManager.handleCallMessage(
            ICON_GOVERNANCE,
            configureProtocolsMessage.encodeConfigureProtocols(),
            defaultSources
        );

        // Assert
        assertTrue(xCallManager.verifyProtocols(newSources));
        assertFalse(xCallManager.verifyProtocols(defaultSources));
        IXCallManager.Protocols memory protocols = xCallManager.getProtocols();
        assert(
            keccak256(abi.encode(protocols)) ==
                keccak256(
                    abi.encode(
                        IXCallManager.Protocols(newSources, newDestinations)
                    )
                )
        );
    }

    function testProposeRemoval_onlyAdmin() public {
        // Arrange
        vm.prank(address(user));

        // Assert
        vm.expectRevert("onlyAdmin");

        // Act
        xCallManager.proposeRemoval("cx04");
    }

    function testConfigureProtocols_withProposal_doesNotExist() public {
        // Arrange
        vm.prank(address(xCall));
        newSources = ["0x045", "0x046"];
        newDestinations = ["cx35", "cx36"];
        deliverySources = [defaultSources[0]];

        Messages.ConfigureProtocols memory configureProtocolsMessage = Messages
            .ConfigureProtocols(newSources, newDestinations);

        // Assert
        vm.expectRevert("No proposal for removal exists");

        // Act
        xCallManager.handleCallMessage(
            ICON_GOVERNANCE,
            configureProtocolsMessage.encodeConfigureProtocols(),
            deliverySources
        );
    }

    function testConfigureProtocols_withProposal() public {
        // Arrange
        newSources = ["0x045", "0x046"];
        newDestinations = ["cx35", "cx36"];
        deliverySources = [defaultSources[0]];
        string memory brokenSource = defaultSources[1];

        Messages.ConfigureProtocols memory configureProtocolsMessage = Messages
            .ConfigureProtocols(newSources, newDestinations);
        vm.prank(admin);
        xCallManager.whitelistAction(
            configureProtocolsMessage.encodeConfigureProtocols()
        );

        // Act
        vm.prank(address(admin));
        xCallManager.proposeRemoval(brokenSource);
        vm.prank(address(xCall));
        xCallManager.handleCallMessage(
            ICON_GOVERNANCE,
            configureProtocolsMessage.encodeConfigureProtocols(),
            deliverySources
        );

        // Assert
        assertTrue(xCallManager.verifyProtocols(newSources));
        assertFalse(xCallManager.verifyProtocols(defaultSources));
        IXCallManager.Protocols memory protocols = xCallManager.getProtocols();
        assert(
            keccak256(abi.encode(protocols)) ==
                keccak256(
                    abi.encode(
                        IXCallManager.Protocols(newSources, newDestinations)
                    )
                )
        );
    }

    function testSetProtocols() public {
        // Arrange
        newSources = ["0x045", "0x046"];
        newDestinations = ["cx35", "cx36"];

        // Act
        vm.prank(owner);
        xCallManager.setProtocols(newSources, newDestinations);

        // Assert
        assertTrue(xCallManager.verifyProtocols(newSources));
        assertFalse(xCallManager.verifyProtocols(defaultSources));
    }

    function testSetProtocols_onlyOwner() public {
        // Arrange
        newSources = ["0x045", "0x046"];
        newDestinations = ["cx35", "cx36"];

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                user
            )
        );

        // Act
        vm.prank(user);
        xCallManager.setProtocols(newSources, newDestinations);
    }

    function testUpgrade_notOwner() public {
        // Arrange
        address xCallManagerAddress = address(new XCallManager());
        vm.prank(user);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        xCallManager.upgradeToAndCall(xCallManagerAddress, "");
    }

    function testUpgrade() public {
        // Arrange
        address xCallManagerAddress = address(new XCallManager());
        vm.prank(owner);

        // Act
        xCallManager.upgradeToAndCall(xCallManagerAddress, "");

        // Assert
        assertEq(xCallManagerAddress, xCallManager.getImplementation());
    }
}
