// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig, Constants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionByConfig() public returns (uint256, address) {
        // get helper config
        HelperConfig helperConfig = new HelperConfig();
        // get vrf coord from config
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(block.chainid);
        // call create subscription on vrf coordinator mock contract
        (uint256 subId, ) = createSub(config._vrfCoordinator, config._account);
        // get and return subId
        return (subId, config._vrfCoordinator);
    }

    function createSub(
        address vrfCoord,
        address account
    ) public returns (uint256, address) {
        VRFCoordinatorV2_5Mock vrfCoordMock = VRFCoordinatorV2_5Mock(vrfCoord);
        vm.startBroadcast(account);
        uint256 subId = vrfCoordMock.createSubscription();
        vm.stopBroadcast();
        return (subId, vrfCoord);
    }

    function run() external {
        createSubscriptionByConfig();
    }
}

contract FundSubscription is Constants, Script {
    uint256 public constant FUND_LINK = 10 ether; // 10 LINK

    // fund subscription for the link token
    function fundSubscriptionWithConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(block.chainid);
        // fund subscription
        fundSubscription(
            config._vrfCoordinator,
            config._subId,
            config._linkToken,
            config._account
        );
    }

    function fundSubscription(
        address vrfCoord,
        uint256 subId,
        address linkToken,
        address account
    ) public {
        // fund sub for local chain with link token
        if (block.chainid == LOCAL_CHAIN_ID) {
            VRFCoordinatorV2_5Mock vrfCoordMock = VRFCoordinatorV2_5Mock(
                vrfCoord
            );
            vm.startBroadcast();
            vrfCoordMock.fundSubscription(subId, FUND_LINK * 100);
            vm.stopBroadcast();
        } else {
            // fund sub for vrf coord with link token for non local chains
            LinkToken _linkToken = LinkToken(linkToken);
            vm.startBroadcast(account);
            _linkToken.transferAndCall(vrfCoord, FUND_LINK, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionWithConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address consumerAddr) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(block.chainid);
        addConsumer(
            config._vrfCoordinator,
            config._subId,
            consumerAddr,
            config._account
        );
    }

    function addConsumer(
        address vrfCoord,
        uint256 subId,
        address consumer,
        address account
    ) public {
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoord).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployedRaffle = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployedRaffle);
    }
}

// vrf coordinator
// subscription
// fund sub
// add consumer on sub
