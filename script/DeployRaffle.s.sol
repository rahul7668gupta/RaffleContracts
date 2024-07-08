// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract()
        public
        returns (Raffle, HelperConfig.NetworkConfig memory)
    {
        // get helper config
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(block.chainid);

        // create a sub if its not present
        if (config._subId == 0) {
            // create sub
            CreateSubscription subCreator = new CreateSubscription();
            (config._subId, ) = subCreator.createSub(config._vrfCoordinator, config._account);
            // fund sub
            FundSubscription subFunder = new FundSubscription();
            subFunder.fundSubscription(
                config._vrfCoordinator,
                config._subId,
                config._linkToken,
                config._account
            );
        }

        // deploy raffle
        vm.startBroadcast(config._account);
        Raffle raffle = new Raffle(
            config._entranceFee,
            config._interval,
            config._vrfCoordinator,
            config._keyHash,
            config._subId,
            config._callbackGasLimit
        );
        vm.stopBroadcast();
        // add consumer
        AddConsumer consumerAdder = new AddConsumer();
        consumerAdder.addConsumer(
            config._vrfCoordinator,
            config._subId,
            address(raffle),
            config._account
        );
        return (raffle, config);
    }
}
