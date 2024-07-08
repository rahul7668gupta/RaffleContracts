// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig, Constants} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

// deploy raffle

contract RaffleTest is Test, Constants {
    Raffle public raffle;
    HelperConfig.NetworkConfig public config;
    /* Config Values */
    uint256 public s_entranceFee;
    uint256 public s_interval;
    address public s_vrfCoordinator;
    bytes32 public s_keyHash;
    uint256 public s_subId;
    uint32 public s_callbackGasLimit;

    address public User1 = makeAddr("User1");
    address public User2 = makeAddr("User2");
    address public User3 = makeAddr("User3");

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Entered(address indexed player);
    event WinnerPicked(address indexed player);

    function setUp() external {
        // new raffle deployer
        DeployRaffle raffleDeployer = new DeployRaffle();
        // deploy raffle
        (raffle, config) = raffleDeployer.deployContract();
        s_entranceFee = config._entranceFee;
        s_interval = config._interval;
        s_vrfCoordinator = config._vrfCoordinator;
        s_keyHash = config._keyHash;
        s_subId = config._subId;
        s_callbackGasLimit = config._callbackGasLimit;
    }

    // test raffle init in open state
    function testRaffleInitInOpenState() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function testEnterRaffleFailsWhenNotEnoughEthIsSent() external {
        vm.deal(User1, 1 ether);
        vm.expectRevert(Raffle.Raffle__SendMoreEthToEnterRaffle.selector);
        vm.prank(User1);
        raffle.enterRaffle();
    }

    function testEnterRaffleSucess() external {
        vm.deal(User1, 1 ether);
        vm.prank(User1);
        // expect emit
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Entered(User1);
        raffle.enterRaffle{value: s_entranceFee}();
        // player should get added into the array
        assert(raffle.getRafflePlayers(0) == User1);
    }

    function testEnterRaffleFailsWhenRaffleIsNotOpen() external {
        // enter raffle from 2 players
        vm.deal(User1, 1 ether);
        vm.prank(User1);
        raffle.enterRaffle{value: s_entranceFee}();

        vm.deal(User2, 1 ether);
        vm.prank(User2);
        raffle.enterRaffle{value: s_entranceFee}();
        // warp to time gt block ts + interval + 1
        vm.warp(block.timestamp + s_interval + 1);
        vm.roll(block.number + 1);
        // call perform upkeep
        raffle.performUpkeep("");
        // enter raffle again fails
        vm.deal(User3, 1 ether);
        vm.prank(User3);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: s_entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/

    // fails when interval is not passed
    // fails when raffle is not open
    // fails when contract doens't have players
    // faile when contracts doens't have any balance
    // passes when all conditions are true

    function testCheckUpkeepFalseWhenIntervalIsNotPassed() external {
        // arrange
        // enter raffle for contract balance
        vm.deal(User1, 1 ether);
        vm.prank(User1);
        raffle.enterRaffle{value: s_entranceFee}();
        // interval not passed
        vm.warp(block.timestamp + s_interval - 1);
        vm.roll(block.number + 1);
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(address(raffle).balance > 0);
        assert(raffle.getRafflePlayers(0) == User1);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(upKeepNeeded == false);
    }

    function testCheckUpkeepFalseWhenRaffleIsNotOpen() external {
        // arrange
        vm.warp(block.timestamp + s_interval + 1);
        vm.roll(block.number + 1);
        // enter raffle for contract balance
        vm.deal(User1, 1 ether);
        vm.prank(User1);
        raffle.enterRaffle{value: s_entranceFee}();
        // execute perform upkeep success
        raffle.performUpkeep("");
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(address(raffle).balance > 0);
        assert(raffle.getRafflePlayers(0) == User1);
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        assert(upKeepNeeded == false);
    }

    function testCheckUpkeepFalseWhenNoPlayersAndBalanceInRaffle() external {
        // arrange
        vm.warp(block.timestamp + s_interval + 1);
        vm.roll(block.number + 1);
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(address(raffle).balance == 0);
        assert(raffle.getRafflePlayersLength() == 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(upKeepNeeded == false);
    }

    function testCheckUpkeepTrueWhenAllConditionsMet() external {
        // arrange
        // enter raffle for contract balance
        vm.deal(User1, 1 ether);
        vm.prank(User1);
        raffle.enterRaffle{value: s_entranceFee}();
        vm.warp(block.timestamp + s_interval + 1);
        vm.roll(block.number + 1);
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(address(raffle).balance > 0);
        assert(raffle.getRafflePlayers(0) == User1);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(upKeepNeeded == true);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructor() external view {
        assertEq(raffle.getEntranceFee(), s_entranceFee);
        assertEq(raffle.getIntervalFee(), s_interval);
        assertEq(raffle.getKeyHash(), s_keyHash);
        assertEq(raffle.getSubId(), s_subId);
        assertEq(raffle.getCallbackGasLimit(), s_callbackGasLimit);
        assertEq(raffle.getLastTimestamp(), block.timestamp);
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.OPEN)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/

    // perform upkeep fails when check upkeep is false
    function testPerformUpkeepFailsWhenCheckUpkeepIsFalse() external {
        vm.deal(User1, 1 ether);
        vm.prank(User1);
        raffle.enterRaffle{value: s_entranceFee}();
        // interval not passed
        vm.warp(block.timestamp + s_interval - 1);
        vm.roll(block.number + 1);
        // act/assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                block.timestamp - raffle.getLastTimestamp(),
                raffle.getRafflePlayersLength(),
                address(raffle).balance,
                raffle.getRaffleState()
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        hoax(User1, 1 ether);
        raffle.enterRaffle{value: s_entranceFee}();
        _;
    }

    // perform upkeep success
    function testPerformUpkeepSuccess() external raffleEntered {
        vm.deal(User1, 1 ether);
        vm.prank(User1);
        raffle.enterRaffle{value: s_entranceFee}();
        // interval passed
        vm.warp(block.timestamp + s_interval + 1);
        vm.roll(block.number + 1);
        // act/assert
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        bytes32 requestId = recordedLogs[1].topics[1];
        // assert logs are correct
        assert(uint256(requestId) > 0);
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.CALCULATING)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        VRF FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/
    // fuzz test vrf coord fulfill randomw words func

    function testFulfillRandomWordsFailsWithoutPerformUpkeep(
        uint256 requestId
    ) external skipForkTest {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(config._vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );
    }

    modifier skipForkTest() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFullFillRandomWordsWhenPerformUpkeepIsCalledWith4Players()
        external
        raffleEntered
        skipForkTest
    {
        uint256 additionalPlayers = 3;
        address expectedWiner = address(1);

        for (uint256 i = 1; i < 1 + additionalPlayers; i++) {
            // for each player, enter raffle
            hoax(address(uint160(i)), 1 ether);
            raffle.enterRaffle{value: s_entranceFee}();
        }

        // move past interval time to execture upkeep
        vm.warp(block.timestamp + s_interval + 1);
        vm.roll(block.number + 1);
        // call perform upkeep and get logs to get the request id;
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        bytes32 requestId = recordedLogs[1].topics[1];

        uint256 winnerStartingBalance = expectedWiner.balance;

        // call fulfill random words on vrf coordinator
        // vm.expectEmit();
        // emit WinnerPicked(expectedWiner);
        VRFCoordinatorV2_5Mock(s_vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // assert
        address winner = raffle.getRaffleWinner();
        assertEq(winner, expectedWiner);
        assertEq(raffle.getRafflePlayersLength(), 0);
        assertEq(raffle.getLastTimestamp(), block.timestamp);
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.OPEN)
        );
        assertEq(
            expectedWiner.balance,
            winnerStartingBalance + (s_entranceFee * 4)
        );
    }
}
