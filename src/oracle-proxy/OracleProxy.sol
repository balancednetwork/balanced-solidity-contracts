// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

interface IPassivePool {
    function rate() external view returns (uint);
}


contract OracleProxy is UUPSUpgradeable, OwnableUpgradeable {
    using RLPEncodeStruct for Messages.UpdatePriceData;

    address public xCall;
    string public iconOracle;
    address public xCallManager;
    address public hiYieldPassivePool;

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


    function configureHiYield(address _passivePool) external onlyOwner {
        hiYieldPassivePool = _passivePool;
    }

    /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function updateHiYeildPrice() external payable {
        Messages.UpdatePriceData memory hiYeildPriceData = fetchHiYeildPrice();

        IXCallManager.Protocols memory protocols = IXCallManager(xCallManager)
            .getProtocols();
        ICallService(xCall).sendCallMessage{value: msg.value}(
            iconOracle,
            hiYeildPriceData.encodeUpdatePriceData(),
            "0x",
            protocols.sources,
            protocols.destinations
        );
    }

    function fetchHiYeildPrice() internal view returns(Messages.UpdatePriceData memory) {
        uint rate = IPassivePool(hiYieldPassivePool).rate();
        // Normalize to 18 decimals and nano second timestamp

        return Messages.UpdatePriceData(
            "hyUSDC",
            rate * 10**12,
            block.timestamp*1000000
        );
    }
}
