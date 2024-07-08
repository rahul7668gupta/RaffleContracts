// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract Constants {
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;

    /* VRF Mock Values */
    uint96 constant VRF_BASE_FEE = 0.25 ether;
    uint96 constant VRF_GAS_PRICE = 1e9;
    int256 constant VRF_LINK_PRICE_IN_WEI = 4e15;
}

contract HelperConfig is Script, Constants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 _entranceFee;
        uint256 _interval;
        address _vrfCoordinator;
        bytes32 _keyHash;
        uint256 _subId;
        uint32 _callbackGasLimit;
        address _linkToken;
        address _account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId]._vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig._vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            VRF_BASE_FEE,
            VRF_GAS_PRICE,
            VRF_LINK_PRICE_IN_WEI
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                _entranceFee: 0.01 ether,
                _interval: 30 seconds,
                _vrfCoordinator: address(vrfCoordinatorMock),
                // doesn't matter
                _keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                _subId: 0, // need to fix this
                _callbackGasLimit: 500000,
                _linkToken: address(linkToken),
                _account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
            });
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                _entranceFee: 0.01 ether,
                _interval: 30 seconds,
                _vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                _keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                _subId: 26364410479862846528568645951564712316894878683936159045373392401967466330289,
                _callbackGasLimit: 1e6,
                _linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                _account: 0x870eecB57dE0903D5E8f187441190c3e83cd94bd
            });
    }
}
