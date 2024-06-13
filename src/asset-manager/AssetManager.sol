// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@iconfoundation/xcall-solidity-library/utils/NetworkAddress.sol";
import "@iconfoundation/xcall-solidity-library/utils/Strings.sol";
import "@iconfoundation/xcall-solidity-library/utils/ParseAddress.sol";
import "@iconfoundation/xcall-solidity-library/interfaces/ICallService.sol";
import "@iconfoundation/xcall-solidity-library/interfaces/ICallServiceReceiver.sol";
import "./Messages.sol";
import "./RLPEncodeStruct.sol";
import "./RLPDecodeStruct.sol";
import "../lib/interfaces/IXCallManager.sol";

contract AssetManager is
    ICallServiceReceiver,
    UUPSUpgradeable,
    OwnableUpgradeable
{
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
    address public constant NATIVE_ADDRESS = address(0);

    mapping(address => uint) public period;
    mapping(address => uint) public percentage;
    mapping(address => uint) public lastUpdate;
    mapping(address => uint) public currentLimit;

    uint private constant POINTS = 10_000;
    uint private constant DAY_IN_SECONDS = 86_400;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _xCall,
        string memory _iconAssetManager,
        address _xCallManager
    ) public initializer {
        require(_xCall != address(0) || _xCallManager != address(0), "Zero address not allowed");
        xCall = _xCall;
        xCallNetworkAddress = ICallService(xCall).getNetworkAddress();
        iconAssetManager = _iconAssetManager;
        xCallManager = _xCallManager;
        __Ownable_init(msg.sender);
    }

    /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    modifier onlyCallService() {
        require(msg.sender == xCall, "onlyCallService");
        _;
    }

    function configureRateLimit(
        address token,
        uint _period,
        uint _percentage
    ) external onlyOwner {
        require(_percentage <= POINTS,"Percentage should be less than or equal to POINTS");
        require(_period <= DAY_IN_SECONDS*30, "Period should be less than or equal to 30 days");

        period[token] = _period;
        percentage[token] = _percentage;
        lastUpdate[token] = block.timestamp;
        currentLimit[token] = (balanceOf(token) * _percentage) / POINTS;
    }

    function resetLimit(address token) external onlyOwner {
        currentLimit[token] = (balanceOf(token) * percentage[token]) / POINTS;
    }

   function getWithdrawLimit(address token) external view returns (uint)  {
        uint balance = balanceOf(token);
        return calculateLimit(balance, token);
    }

    function verifyWithdraw(address token, uint amount) internal {
        uint balance = balanceOf(token);
        uint limit = calculateLimit(balance, token);
        require(balance - amount >= limit, "exceeds withdraw limit");

        currentLimit[token] = limit;
        lastUpdate[token] = block.timestamp;
    }

    function calculateLimit(uint balance, address token) internal view returns (uint) {
        uint _period = period[token];
        uint _percentage = percentage[token];
        if (_period == 0) {
            return 0;
        }

        uint maxLimit = (balance * _percentage) / POINTS;
        // The maximum amount that can be withdraw in one period
        uint maxWithdraw = balance - maxLimit;
        uint timeDiff = block.timestamp - lastUpdate[token];
        timeDiff = Math.min(timeDiff, _period);

        // The amount that should be added as availbe
        uint addedAllowedWithdrawal = (maxWithdraw * timeDiff) / _period;
        uint limit = currentLimit[token] - addedAllowedWithdrawal;
        // If the balance is below the limit then set limt to current balance (no withdraws are possible)
        limit = Math.min(balance, limit);
        // If limit goes below what the protected percentage is set it to the maxLimit
        return  Math.max(limit, maxLimit);
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

    function depositNative(uint amount) external payable {
        _depositNative(amount, "", "");
    }

    function depositNative(uint amount, string memory to) external payable {
        _depositNative(amount, to, "");
    }

    function depositNative(
        uint amount,
        string memory to,
        bytes memory data
    ) external payable {
        _depositNative(amount, to, data);
    }

    function _deposit(
        address token,
        uint amount,
        string memory to,
        bytes memory data
    ) internal {
        require(amount > 0, "Amount less than minimum amount");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        sendDepositMessage(token, amount, to, data, msg.value);
    }

    function _depositNative(
        uint amount,
        string memory to,
        bytes memory data
    ) internal {
        require(msg.value >= amount, "Amount less than minimum amount");
        uint fee = msg.value - amount;
        sendDepositMessage(NATIVE_ADDRESS, amount, to, data, fee);
    }

    function sendDepositMessage(
        address token,
        uint amount,
        string memory to,
        bytes memory data,
        uint fee
    ) internal {
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
        ICallService(xCall).sendCallMessage{value: fee}(
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
        require(amount > 0, "Amount less than minimum amount");
        verifyWithdraw(token, amount);
        if (token == NATIVE_ADDRESS) {
            bool sent = payable(to).send(amount);
            require(sent, "Failed to send tokens");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function balanceOf(address token) internal view returns (uint) {
        if (token == NATIVE_ADDRESS) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }
}
