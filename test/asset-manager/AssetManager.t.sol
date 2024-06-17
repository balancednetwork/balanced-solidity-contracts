// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@balanced/contracts/asset-manager/AssetManager.sol";
import "@balanced/contracts/asset-manager/Messages.sol";
import "@balanced/contracts/lib/interfaces/IXCallManager.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@iconfoundation/xcall-solidity-library/interfaces/ICallService.sol";
import "@iconfoundation/xcall-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/xcall-solidity-library/utils/Strings.sol";
import "@iconfoundation/xcall-solidity-library/utils/ParseAddress.sol";

contract TokenContract is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public virtual returns (bool) {
        _mint(account, amount);
        return true;
    }
}

contract AssetManagerTest is Test {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.Deposit;
    using RLPEncodeStruct for Messages.DepositRevert;
    using RLPEncodeStruct for Messages.WithdrawTo;

    address public user = address(0x1234);
    address public owner = address(0x2345);
    AssetManager public assetManager;
    IXCallManager public xCallManager;
    ICallService public xCall;
    TokenContract public token;
    string public constant nid = "0x1.eth";
    string public constant ICON_ASSET_MANAGER = "0x1.icon/cx1";
    string[] defaultSources = ["0x05", "0x06"];
    string[] defaultDestinations = ["cx2", "cx3"];

    function setUp() public {
        xCall = ICallService(address(0x01));
        xCallManager = IXCallManager(address(0x02));
        token = new TokenContract(
            "TestToken",
            "TST"
        );

        token.mint(user, 1000);

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

        assetManager = new AssetManager();
        address assetManagerAddress = address(assetManager);
        vm.prank(owner);
        assetManager = AssetManager(
            address(
                new ERC1967Proxy(
                    assetManagerAddress,
                    abi.encodeWithSelector(
                        assetManager.initialize.selector,
                        address(xCall),
                        ICON_ASSET_MANAGER,
                        address(xCallManager)
                    )
                )
            )
        );
    }

    function testDeposit_base() public {
        // Arrange
        uint amount = 100;
        uint256 fee = 10 ether;
        vm.deal(user, fee);
        vm.prank(user);
        token.approve(address(assetManager), amount);

        vm.prank(user);

        Messages.Deposit memory xcallMessage = Messages.Deposit(
            address(token).toString(),
            address(user).toString(),
            "",
            amount,
            ""
        );
        Messages.DepositRevert memory rollback = Messages.DepositRevert(
            address(token),
            amount,
            address(user)
        );

        vm.mockCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(xCall.sendCallMessage.selector),
            abi.encode(0)
        );

        vm.expectCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(
                xCall.sendCallMessage.selector,
                ICON_ASSET_MANAGER,
                xcallMessage.encodeDeposit(),
                rollback.encodeDepositRevert(),
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        assetManager.deposit{value: fee}(address(token), amount);
    }

    function testDepositNative_base() public {
        // Arrange
        uint256 amount = 100 ether;
        uint256 fee = 10 ether;
        uint256 value = amount + fee;
        vm.deal(user, value);
        vm.prank(user);

        Messages.Deposit memory xcallMessage = Messages.Deposit(
            address(0).toString(),
            address(user).toString(),
            "",
            amount,
            ""
        );
        Messages.DepositRevert memory rollback = Messages.DepositRevert(
            address(0),
            amount,
            address(user)
        );

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
                ICON_ASSET_MANAGER,
                xcallMessage.encodeDeposit(),
                rollback.encodeDepositRevert(),
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        assetManager.depositNative{value: value}(amount);
    }

    function testDeposit_with_to() public {
        // Arrange
        uint amount = 100;
        uint256 fee = 10 ether;
        string memory to = "0x1.icon/hx4";
        vm.deal(user, fee);

        vm.prank(user);
        token.approve(address(assetManager), amount);

        vm.prank(user);

        Messages.Deposit memory xcallMessage = Messages.Deposit(
            address(token).toString(),
            address(user).toString(),
            to,
            amount,
            ""
        );
        Messages.DepositRevert memory rollback = Messages.DepositRevert(
            address(token),
            amount,
            address(user)
        );

        vm.mockCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(xCall.sendCallMessage.selector),
            abi.encode(0)
        );

        vm.expectCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(
                xCall.sendCallMessage.selector,
                ICON_ASSET_MANAGER,
                xcallMessage.encodeDeposit(),
                rollback.encodeDepositRevert(),
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        assetManager.deposit{value: fee}(address(token), amount, to);
    }

    function testDeposit_with_data() public {
        // Arrange
        uint amount = 100;
        uint256 fee = 10 ether;
        string memory to = "0x1.icon/cx5";
        bytes memory data = "swap";
        vm.deal(user, fee);
        vm.prank(user);
        token.approve(address(assetManager), amount);

        Messages.Deposit memory xcallMessage = Messages.Deposit(
            address(token).toString(),
            address(user).toString(),
            to,
            amount,
            data
        );
        Messages.DepositRevert memory rollback = Messages.DepositRevert(
            address(token),
            amount,
            address(user)
        );

        vm.mockCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(xCall.sendCallMessage.selector),
            abi.encode(0)
        );

        vm.expectCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(
                xCall.sendCallMessage.selector,
                ICON_ASSET_MANAGER,
                xcallMessage.encodeDeposit(),
                rollback.encodeDepositRevert(),
                defaultSources,
                defaultDestinations
            )
        );
        vm.prank(user);
        // Act
        assetManager.deposit{value: fee}(address(token), amount, to, data);
    }

    function testhandleCallMessage_OnlyXCall() public {
        // Arrange
        vm.prank(user);

        // Assert
        vm.expectRevert("onlyCallService");

        // Act
        assetManager.handleCallMessage("", "", defaultSources);
    }

    function testhandleCallMessage_InvalidProtocol() public {
        // Arrange
        vm.prank(address(xCall));

        // Assert
        vm.expectRevert("Protocol Mismatch");

        // Act
        assetManager.handleCallMessage("", "", defaultDestinations);
    }

    function testWithdrawTo_onlyICONAssetManager() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;

        Messages.WithdrawTo memory withdrawToMessage = Messages.WithdrawTo(
            address(token).toString(),
            address(user).toString(),
            amount
        );

        // Assert
        vm.expectRevert("onlyICONAssetManager");

        // Act
        assetManager.handleCallMessage(
            "not icon asset manager",
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );
    }

    function testWithdrawTom() public {
        // Arrange
        uint amount = 100;
        vm.prank(address(user));
        token.transfer(address(assetManager), amount);

        vm.prank(address(xCall));
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transfer.selector),
            abi.encode(1)
        );
        Messages.WithdrawTo memory withdrawToMessage = Messages.WithdrawTo(
            address(token).toString(),
            address(user).toString(),
            amount
        );

        // Act
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );
    }

    function testWithdrawTo_native() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100 ether;
        vm.deal(address(assetManager), amount);

        Messages.WithdrawTo memory withdrawToMessage = Messages.WithdrawTo(
            address(0).toString(),
            address(user).toString(),
            amount
        );

        // Act
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        // Assert
        assertEq(amount, address(user).balance);
    }

    function testWithdrawNativeTo() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;
        Messages.WithdrawTo memory withdrawToMessage = Messages.WithdrawTo(
            address(token).toString(),
            address(user).toString(),
            amount
        );

        // Assert
        vm.expectRevert("Withdraw to native is currently not supported");

        // Act
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawNativeTo(),
            defaultSources
        );
    }

    function testWithdrawLimits() public {
        // Arrange
        uint balance = 100 ether;
        uint amount = 9 ether;
        uint percentage = 9000; // 90 %
        uint period = 1000; // over every 1000 secounds which mean 10% loss of balance per 1000 seconds
        vm.deal(address(assetManager), balance);
        vm.prank(owner);
        assetManager.configureRateLimit(address(0), period, percentage);
        assertEq(assetManager.currentLimit(address(0)), 90 ether);

        Messages.WithdrawTo memory withdrawToMessage = Messages.WithdrawTo(
            address(0).toString(),
            address(user).toString(),
            amount
        );

        // Act
        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        vm.expectRevert("exceeds withdraw limit");

        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        vm.warp(block.timestamp + 1001);
        uint limit = assetManager.getWithdrawLimit(address(0));
        assertEq(limit, 91 ether * 90 / 100);
        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        // Assert
        assertEq(amount*2, address(user).balance);
    }


    function testWithdrawLimits_staleWithdraws() public {
        // Arrange
        uint balance = 100 ether;
        uint amount = 9 ether;
        uint percentage = 9000; // 90 %
        uint period = 1000; // over every 1000 secounds which mean 10% loss of balance per 1000 seconds
        vm.deal(address(assetManager), balance);
        vm.prank(owner);
        assetManager.configureRateLimit(address(0), period, percentage);
        assertEq(assetManager.currentLimit(address(0)), 90 ether);

        Messages.WithdrawTo memory withdrawToMessage = Messages.WithdrawTo(
            address(0).toString(),
            address(user).toString(),
            amount
        );

        // Act
        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        vm.expectRevert("exceeds withdraw limit");

        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        vm.warp(block.timestamp + 10001);

        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        // Assert
        assertEq(amount*2, address(user).balance);
    }


    function testWithdrawLimits_reset() public {
        // Arrange
        uint balance = 100 ether;
        uint amount = 9 ether;
        uint percentage = 9000; // 90 %
        uint period = 1000; // over every 1000 secounds which mean 10% loss of balance per 1000 seconds
        vm.deal(address(assetManager), balance);
        vm.prank(owner);
        assetManager.configureRateLimit(address(0), period, percentage);

        Messages.WithdrawTo memory withdrawToMessage = Messages.WithdrawTo(
            address(0).toString(),
            address(user).toString(),
            amount
        );

        // Act
        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        vm.expectRevert("exceeds withdraw limit");

        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        vm.prank(owner);
        assetManager.resetLimit(address(0));

        vm.prank(address(xCall));
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            withdrawToMessage.encodeWithdrawTo(),
            defaultSources
        );

        // Assert
        assertEq(amount * 2, address(user).balance);
    }

    function testDepositRollback_onlyCallService() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;
        Messages.DepositRevert memory depositRevertMessage = Messages
            .DepositRevert(address(token), amount, address(user));

        // Assert
        vm.expectRevert("onlyCallService");

        // Act
        assetManager.handleCallMessage(
            ICON_ASSET_MANAGER,
            depositRevertMessage.encodeDepositRevert(),
            defaultSources
        );
    }

    function testDepositRollback() public {
        // Arrange
        uint amount = 100;
        vm.prank(address(user));
        token.transfer(address(assetManager), amount);
        
        vm.prank(address(xCall));
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transfer.selector),
            abi.encode(1)
        );

        Messages.DepositRevert memory depositRevertMessage = Messages
            .DepositRevert(address(token), amount, address(user));

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
        assetManager.handleCallMessage(
            nid.networkAddress(address(xCall).toString()),
            depositRevertMessage.encodeDepositRevert(),
            defaultSources
        );
    }

    function testDepositRollback_native() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100 ether;
        vm.deal(address(assetManager), amount);

        Messages.DepositRevert memory depositRevertMessage = Messages
            .DepositRevert(address(0), amount, address(user));

        // Act
        assetManager.handleCallMessage(
            nid.networkAddress(address(xCall).toString()),
            depositRevertMessage.encodeDepositRevert(),
            defaultSources
        );

        // Assert
        assertEq(amount, address(user).balance);
    }

    function testHandleCallMessage_unknownMessage() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;
        Messages.Deposit memory xcallMessage = Messages.Deposit(
            address(token).toString(),
            address(user).toString(),
            "",
            amount,
            ""
        );

        // Assert
        vm.expectRevert("Unknown message type");

        // Act
        assetManager.handleCallMessage(
            nid.networkAddress(address(xCall).toString()),
            xcallMessage.encodeDeposit(),
            defaultSources
        );
    }

    function testUpgrade_notOwner() public {
        // Arrange
        address assetManagerAddress = address(new AssetManager());
        vm.prank(user);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        assetManager.upgradeToAndCall(assetManagerAddress, "");
    }

    function testUpgrade() public {
        // Arrange
        address assetManagerAddress = address(new AssetManager());
        vm.prank(owner);

        // Act
        assetManager.upgradeToAndCall(assetManagerAddress, "");

        // Assert
        assertEq(assetManagerAddress, assetManager.getImplementation());
    }
}
