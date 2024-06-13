// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import "forge-std/interfaces/IERC4626.sol";
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
import "../lib/interfaces/IXCallManager.sol";

contract OracleProxy is UUPSUpgradeable, OwnableUpgradeable {
    using RLPEncodeStruct for Messages.UpdatePriceData;

    address public xCall;
    string public iconOracle;
    address public xCallManager;
    mapping(address => bool) public creditVaults;

    uint private constant MICROSECONDS_IN_SECONDS = 1_000_000;


    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _xCall,
        string memory _iconOracle,
        address _xCallManager
    ) public initializer {
        xCall = _xCall;
        iconOracle = _iconOracle;
        xCallManager = _xCallManager;
        __Ownable_init(msg.sender);
    }

    function configure(
        address _xCall,
        string memory _iconOracle,
        address _xCallManager
    ) external onlyOwner {
        xCall = _xCall;
        iconOracle = _iconOracle;
        xCallManager = _xCallManager;
    }


    function addCreditVault(address _vault) external onlyOwner {
        creditVaults[_vault] = true;
    }

    function removeCreditVault(address _vault) external onlyOwner {
        delete creditVaults[_vault];
    }

    /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function updateCreditVaultPrice(address _vault) external payable {
        require(creditVaults[_vault], "Credit vault not whitelisted");
        Messages.UpdatePriceData memory priceData = fetchCreditVaultPrice(_vault);

        IXCallManager.Protocols memory protocols = IXCallManager(xCallManager)
            .getProtocols();
        ICallService(xCall).sendCallMessage{value: msg.value}(
            iconOracle,
            priceData.encodeUpdatePriceData(),
            "",
            protocols.sources,
            protocols.destinations
        );
    }

    function fetchCreditVaultPrice(address _vault) internal view returns(Messages.UpdatePriceData memory) {
        string memory symbol = IERC4626(_vault).symbol();
        uint sharesDecimals = IERC4626(_vault).decimals();
        address asset = IERC4626(_vault).asset();
        uint assetDecimals  = IERC20(asset).decimals();
        uint rate = IERC4626(_vault).convertToAssets(10**sharesDecimals);
        // convert to 18 decimal
        rate = rate * 10**(18-assetDecimals);

        return Messages.UpdatePriceData(
            symbol,
            rate,
            block.timestamp*MICROSECONDS_IN_SECONDS
        );
    }
}
