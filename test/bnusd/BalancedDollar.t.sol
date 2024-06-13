// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@balanced/contracts/bnusd/BalancedDollar.sol";
import "@balanced/contracts/bnusd/Messages.sol";
import "@balanced/contracts/lib/interfaces/IXCallManager.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@iconfoundation/xcall-solidity-library/interfaces/ICallService.sol";
import "@iconfoundation/xcall-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/xcall-solidity-library/utils/Strings.sol";
import "@iconfoundation/xcall-solidity-library/utils/ParseAddress.sol";

contract BalancedDollarTest is Test {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.XCrossTransfer;
    using RLPEncodeStruct for Messages.XCrossTransferRevert;

    address public user = address(0x1234);
    address public owner = address(0x2345);
    BalancedDollar public bnUSD;
    IXCallManager public xCallManager;
    ICallService public xCall;
    string public constant nid = "0x1.eth";
    string public constant ICON_BNUSD = "0x1.icon/cx1";
    string[] defaultSources = ["0x05", "0x06"];
    string[] defaultDestinations = ["cx2", "cx3"];

    function setUp() public {
        xCall = ICallService(address(0x01));
        xCallManager = IXCallManager(address(0x02));
        vm.mockCall(
            address(xCall),
            abi.encodeWithSelector(xCall.getNetworkAddress.selector),
            abi.encode(nid.networkAddress(address(xCall).toString()))
        );
        vm.mockCall(
            address(xCallManager),
            abi.encodeWithSelector(xCallManager.getProtocols.selector),
            abi.encode(
                IXCallManager.Protocols(defaultSources, defaultDestinations)
            )
        );
        vm.mockCall(
            address(xCallManager),
            abi.encodeWithSelector(xCallManager.verifyProtocols.selector),
            abi.encode(false)
        );
        vm.mockCall(
            address(xCallManager),
            abi.encodeWithSelector(
                xCallManager.verifyProtocols.selector,
                defaultSources
            ),
            abi.encode(true)
        );

        bnUSD = new BalancedDollar();
        address bnUSDAddress = address(bnUSD);
        vm.prank(owner);
        bnUSD = BalancedDollar(
            address(
                new ERC1967Proxy(
                    bnUSDAddress,
                    abi.encodeWithSelector(
                        bnUSD.initialize.selector,
                        address(xCall),
                        ICON_BNUSD,
                        address(xCallManager)
                    )
                )
            )
        );
    }

    function testCrossTransfer() public {
        // Arrange
        uint amount = 100;
        uint256 fee = 10 ether;
        string memory to = "0x1.icon/hx1";
        vm.deal(user, fee);
        addTokens(user, amount);
        vm.prank(user);

        Messages.XCrossTransfer memory xcallMessage = Messages.XCrossTransfer(
            nid.networkAddress(user.toString()),
            to,
            amount,
            ""
        );
        Messages.XCrossTransferRevert memory rollback = Messages
            .XCrossTransferRevert(user, amount);

        vm.mockCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(xCall.sendCallMessage.selector),
            abi.encode(0)
        );

        // Assert
        vm.expectCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(
                xCall.sendCallMessage.selector,
                ICON_BNUSD,
                xcallMessage.encodeCrossTransfer(),
                rollback.encodeCrossTransferRevert(),
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        bnUSD.crossTransfer{value: fee}(to, amount);

        // Assert
        assertEq(bnUSD.balanceOf(user), 0);
    }

    function testCrossTransferWithData() public {
        // Arrange
        uint amount = 100;
        uint256 fee = 10 ether;
        string memory to = "0x1.icon/hx1";
        bytes memory data = "test";
        vm.deal(user, fee);
        addTokens(user, amount);
        vm.prank(user);

        Messages.XCrossTransfer memory xcallMessage = Messages.XCrossTransfer(
            nid.networkAddress(user.toString()),
            to,
            amount,
            data
        );
        Messages.XCrossTransferRevert memory rollback = Messages
            .XCrossTransferRevert(user, amount);

        vm.mockCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(xCall.sendCallMessage.selector),
            abi.encode(0)
        );

        // Assert
        vm.expectCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(
                xCall.sendCallMessage.selector,
                ICON_BNUSD,
                xcallMessage.encodeCrossTransfer(),
                rollback.encodeCrossTransferRevert(),
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        bnUSD.crossTransfer{value: fee}(to, amount, data);

        // Assert
        assertEq(bnUSD.balanceOf(user), 0);
    }

    function testhandleCallMessage_OnlyXCall() public {
        // Arrange
        vm.prank(user);

        // Assert
        vm.expectRevert("onlyCallService");

        // Act
        bnUSD.handleCallMessage("", "", defaultSources);
    }

    function testhandleCallMessage_InvalidProtocol() public {
        // Arrange
        vm.prank(address(xCall));

        // Assert
        vm.expectRevert("Protocol Mismatch");

        // Act
        bnUSD.handleCallMessage("", "", defaultDestinations);
    }

    function testReceiveCrossTransfer_onlyICONBnUSD() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;

        Messages.XCrossTransfer memory message = Messages.XCrossTransfer(
            "",
            nid.networkAddress(user.toString()),
            amount,
            ""
        );

        // Assert
        vm.expectRevert("onlyICONBnUSD");

        // Act
        bnUSD.handleCallMessage(
            "Not ICON bnUSD",
            message.encodeCrossTransfer(),
            defaultSources
        );
    }

    function testReceiveCrossTransfer() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;

        Messages.XCrossTransfer memory message = Messages.XCrossTransfer(
            "",
            nid.networkAddress(user.toString()),
            amount,
            ""
        );

        // Act
        bnUSD.handleCallMessage(
            ICON_BNUSD,
            message.encodeCrossTransfer(),
            defaultSources
        );

        // Assert
        assertEq(bnUSD.balanceOf(user), amount);
    }

    function testReceiveCrossTransferRevert() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;

        Messages.XCrossTransferRevert memory message = Messages
            .XCrossTransferRevert(user, amount);

        // Act
        bnUSD.handleCallMessage(
            nid.networkAddress(address(xCall).toString()),
            message.encodeCrossTransferRevert(),
            defaultSources
        );

        // Assert
        assertEq(bnUSD.balanceOf(user), amount);
    }

    function testReceiveCrossTransferRevert_onlyXCall() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;

        Messages.XCrossTransferRevert memory message = Messages
            .XCrossTransferRevert(user, amount);

        // Assert
        vm.expectRevert("onlyCallService");

        // Act
        bnUSD.handleCallMessage(
            ICON_BNUSD,
            message.encodeCrossTransferRevert(),
            defaultSources
        );
    }

    function addTokens(address account, uint amount) public {
        vm.prank(address(xCall));
        Messages.XCrossTransfer memory message = Messages.XCrossTransfer(
            "",
            nid.networkAddress(account.toString()),
            amount,
            ""
        );

        bnUSD.handleCallMessage(
            ICON_BNUSD,
            message.encodeCrossTransfer(),
            defaultSources
        );
    }

    function testUpgrade_notOwner() public {
        // Arrange
        address bnUSDAddress = address(new BalancedDollar());
        vm.prank(user);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        bnUSD.upgradeToAndCall(bnUSDAddress, "");
    }

    function testUpgrade() public {
        // Arrange
        address bnUSDAddress = address(new BalancedDollar());
        vm.prank(owner);

        // Act
        bnUSD.upgradeToAndCall(bnUSDAddress, "");

        // Assert
        assertEq(bnUSDAddress, bnUSD.getImplementation());
    }
}
