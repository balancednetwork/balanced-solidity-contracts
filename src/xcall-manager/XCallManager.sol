// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

contract XCallManager is
    IXCallManager,
    ICallServiceReceiver,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.ConfigureProtocols;
    using RLPEncodeStruct for Messages.Execute;
    using RLPDecodeStruct for bytes;

    address public xCall;
    address public admin;
    string private xCallNetworkAddress;
    string public iconGovernance;

    string public proposedProtocolToRemove;

    string[] public sources;
    string[] public destinations;

    mapping(bytes => bool) public whitelistedActions;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _xCall,
        string memory _iconGovernance,
        address _admin,
        string[] memory _sources,
        string[] memory _destinations
    ) public initializer {
        xCall = _xCall;
        xCallNetworkAddress = ICallService(xCall).getNetworkAddress();
        iconGovernance = _iconGovernance;
        admin = _admin;
        _setProtocols(_sources, _destinations);
        __Ownable_init(msg.sender);
    }

    /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "onlyAdmin");
        _;
    }

    modifier onlyCallService() {
        require(msg.sender == xCall, "onlyCallService");
        _;
    }

    function proposeRemoval(string memory protocol) external onlyAdmin {
        proposedProtocolToRemove = protocol;
    }

    function whitelistAction(bytes memory action) external onlyAdmin {
        whitelistedActions[action] = true;
    }

    function removeAction(bytes memory action) external onlyAdmin {
        delete whitelistedActions[action];
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function setProtocols(
        string[] memory _sources,
        string[] memory _destinations
    ) external onlyOwner {
        _setProtocols(_sources, _destinations);
    }

    function _setProtocols(
        string[] memory _sources,
        string[] memory _destinations
    ) internal {
        require(
            !hasDuplicates(_sources),
            "Source protcols cannot contain duplicates"
        );
        require(
            !hasDuplicates(_destinations),
            "Destination protcols cannot contain duplicates"
        );
        sources = _sources;
        destinations = _destinations;
    }

    function verifyProtocols(
        string[] calldata protocols
    ) external view returns (bool) {
        return verifyProtocolsUnordered(sources, protocols);
    }

    function getProtocols() external view returns (Protocols memory) {
        return Protocols(sources, destinations);
    }

    function handleCallMessage(
        string calldata from,
        bytes calldata data,
        string[] calldata protocols
    ) external onlyCallService {
        require(
            from.compareTo(iconGovernance),
            "Only ICON Balanced governance is allowed"
        );
        string memory method = data.getMethod();
        if (!verifyProtocolsUnordered(sources, protocols)) {
            require(
                method.compareTo(Messages.CONFIGURE_PROTOCOLS_NAME),
                "Protocol Mismatch"
            );
            verifyProtocolRecovery(protocols);
        }

        require(
            whitelistedActions[data],
            "Actions in not whitelisted by admin"
        );
        delete whitelistedActions[data];

        if (method.compareTo(Messages.EXECUTE_NAME)) {
            Messages.Execute memory message = data.decodeExecute();
            (bool _success, ) = message.contractAddress.call(message.data);
            require(_success, "Failed to excute message");
        } else if (method.compareTo(Messages.CONFIGURE_PROTOCOLS_NAME)) {
            Messages.ConfigureProtocols memory message = data
                .decodeConfigureProtocols();
            sources = message.sources;
            destinations = message.destinations;
        } else {
            revert("Unknown message type");
        }
    }

    function verifyProtocolRecovery(string[] calldata protocols) internal view {
        string[] memory modifiedSources = getModifiedProtocols();
        require(
            verifyProtocolsUnordered(modifiedSources, protocols),
            "Protocol Mismatch"
        );
    }

    // Verifies that all required protocols exists in the protocols used for delivery.
    function verifyProtocolsUnordered(
        string[] memory requiredProtocols,
        string[] memory deliveryProtocols
    ) internal pure returns (bool) {
        // Check if the arrays have the same length
        if (requiredProtocols.length != deliveryProtocols.length) {
            return false;
        }

        for (uint i = 0; i < requiredProtocols.length; i++) {
            for (uint j = 0; j < deliveryProtocols.length; j++) {
                if (requiredProtocols[i].compareTo(deliveryProtocols[j])) {
                    break;
                }
                if (j == deliveryProtocols.length - 1) return false;
            }
        }

        return true;
    }

    function hasDuplicates(string[] memory arr) internal pure returns (bool) {
        for (uint i = 0; i < arr.length; i++) {
            for (uint j = i + 1; j < arr.length; j++) {
                if (
                    keccak256(abi.encodePacked(arr[i])) ==
                    keccak256(abi.encodePacked(arr[j]))
                ) {
                    return true;
                }
            }
        }
        return false;
    }

    function contains(
        string memory item,
        string[] memory arr
    ) internal pure returns (bool) {
        for (uint i = 0; i < arr.length; i++) {
            if (
                keccak256(abi.encodePacked(arr[i])) ==
                keccak256(abi.encodePacked(item))
            ) {
                return true;
            }
        }
        return false;
    }

    function getModifiedProtocols() internal view returns (string[] memory) {
        require(
            bytes(proposedProtocolToRemove).length != 0 &&
            contains(proposedProtocolToRemove, sources),
            "No proposal for removal exists"
        );

        string[] memory newArray = new string[](sources.length - 1);
        uint newIndex = 0;
        for (uint i = 0; i < sources.length; i++) {
            if (!sources[i].compareTo(proposedProtocolToRemove)) {
                newArray[newIndex] = sources[i];
                newIndex++;
            }
        }

        return newArray;
    }
}
