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

contract XCallManager is IXCallManager, ICallServiceReceiver, UUPSUpgradeable,  OwnableUpgradeable {
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
        sources = _sources;
        destinations = _destinations;
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

    function setAdmin(address _admin) external onlyAdmin() {
        admin = _admin;
    }

    function verifyProtocols(
        string[] calldata protocols
    ) external view returns (bool) {
        return verifyProtocolsUnordered(protocols, sources);
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

        if (!verifyProtocolsUnordered(protocols, sources)) {
            require(
                method.compareTo(Messages.CONFIGURE_PROTOCOLS_NAME),
                "Protocol Mismatch"
            );
            verifyProtocolRecovery(protocols);
        }

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

    function verifyProtocolsUnordered(
        string[] memory array1,
        string[] memory array2
    ) internal pure returns (bool) {
        // Check if the arrays have the same length
        if (array1.length != array2.length) {
            return false;
        }

        for (uint i = 0; i < array1.length; i++) {
            for (uint j = 0; j < array2.length; j++) {
                if (array1[i].compareTo(array2[j])) {
                    break;
                } else {
                    if (j == array2.length - 1) return false;
                    continue;
                }
            }
        }

        return true;
    }

    function getModifiedProtocols() internal view returns (string[] memory) {
        require(
            bytes(proposedProtocolToRemove).length != 0,
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
