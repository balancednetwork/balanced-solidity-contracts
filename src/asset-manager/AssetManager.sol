// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import "@iconfoundation/xcall-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/xcall-solidity-library/utils/Strings.sol";
import "@iconfoundation/xcall-solidity-library/utils/ParseAddress.sol";
import "@iconfoundation/xcall-solidity-library/interfaces/ICallService.sol";
import "@iconfoundation/xcall-solidity-library/interfaces/ICallServiceReceiver.sol";
import "./Messages.sol";
import "./RLPEncodeStruct.sol";
import "./RLPDecodeStruct.sol";
import "../lib/interfaces/IXCallManager.sol";

contract AssetManager is ICallServiceReceiver, UUPSUpgradeable,  OwnableUpgradeable {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.Deposit;
    using RLPEncodeStruct for Messages.DepositRevert;
    using RLPDecodeStruct for bytes;
    using SafeERC20 for IERC20;

    address public xCall;
    string public xCallNetworkAddress;
    string public iconAssetManager;
    address public xCallManager;

    function initialize(
        address _xCall,
        string memory _iconAssetManager,
        address _xCallManager
    ) public initializer {
        xCall = _xCall;
        xCallNetworkAddress = ICallService(xCall).getNetworkAddress();
        iconAssetManager = _iconAssetManager;
        xCallManager = _xCallManager;
        __Ownable_init(msg.sender);
    }

        /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override {}

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    modifier onlyCallService() {
        require(msg.sender == xCall, "onlyCallService");
        _;
    }

    function deposit(address token, uint amount) external payable {
        _deposit(token, amount, "", "");
    }

    function deposit(
        address token,
        uint amount,
        string memory to
    ) external payable {
        _deposit(token, amount, to, "");
    }

    function deposit(
        address token,
        uint amount,
        string memory to,
        bytes memory data
    ) external payable {
        _deposit(token, amount, to, data);
    }

    function _deposit(
        address token,
        uint amount,
        string memory to,
        bytes memory data
    ) internal {
        require(amount > 0, "Amount less than minimum amount");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        Messages.Deposit memory xcallMessage = Messages.Deposit(
            token.toString(),
            msg.sender.toString(),
            to,
            amount,
            data
        );
        Messages.DepositRevert memory rollback = Messages.DepositRevert(
            token,
            amount,
            msg.sender
        );

        IXCallManager.Protocols memory protocols = IXCallManager(xCallManager)
            .getProtocols();
        ICallService(xCall).sendCallMessage{value: msg.value}(
            iconAssetManager,
            xcallMessage.encodeDeposit(),
            rollback.encodeDepositRevert(),
            protocols.sources,
            protocols.destinations
        );
    }

    function handleCallMessage(
        string calldata from,
        bytes calldata data,
        string[] calldata protocols
    ) external onlyCallService {
        require(
            IXCallManager(xCallManager).verifyProtocols(protocols),
            "Protocol Mismatch"
        );

        string memory method = data.getMethod();
        if (method.compareTo(Messages.WITHDRAW_TO_NAME)) {
            require(from.compareTo(iconAssetManager), "onlyICONAssetManager");
            Messages.WithdrawTo memory message = data.decodeWithdrawTo();
            withdraw(
                message.tokenAddress.parseAddress("Invalid account"),
                message.to.parseAddress("Invalid account"),
                message.amount
            );
        } else if (method.compareTo(Messages.WITHDRAW_NATIVE_TO_NAME)) {
            revert("Withdraw to native is currently not supported");
        } else if (method.compareTo(Messages.DEPOSIT_REVERT_NAME)) {
            require(from.compareTo(xCallNetworkAddress), "onlyCallService");
            Messages.DepositRevert memory message = data.decodeDepositRevert();
            withdraw(message.tokenAddress, message.to, message.amount);
        } else {
            revert("Unknown message type");
        }
    }

    function withdraw(address token, address to, uint amount) internal {
        require(amount >= 0, "Amount less than minimum amount");
        IERC20(token).safeTransfer( to, amount);
    }
}
