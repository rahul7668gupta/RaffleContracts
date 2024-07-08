// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample raffle contract
 * @author Rahul Gupta
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /*
    Errors
    */
    error Raffle__SendMoreEthToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 intervalPassed,
        uint256 playersLength,
        uint256 balance,
        RaffleState raffleState
    );
    /*
    Type declarations
    */

    enum RaffleState {
        OPEN,
        CALCULATING
    }
    // constants

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    // entrance fee for raffle
    uint256 private immutable i_entranceFee;
    // time to pass before pick winner can be called in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_winner;
    RaffleState private s_raffleState;

    event Entered(address indexed player);
    event WinnerPicked(address indexed player);
    event RaffleRandomWordsRequested(uint256 indexed requestId);

    constructor(
        uint256 _entraceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = _entraceFee;
        i_interval = _interval;
        i_keyHash = _keyHash;
        i_subId = _subId;
        i_callbackGasLimit = _callbackGasLimit;

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreEthToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit Entered(msg.sender);
    }

    /**
     * @dev this function is called by chainlink automation to check if the upkeep needs to be performed
     * should return true if all of the conditions below are true
     * interval time has passed
     * contract has eth
     * contract has players
     * raffle is open
     * @param - ignored
     * @return upkeepNeeded
     * @return - ignored
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool intervalPassed = block.timestamp - s_lastTimestamp > i_interval;
        bool contractHasEth = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        bool isRaffleOpen = s_raffleState == RaffleState.OPEN;
        upkeepNeeded =
            intervalPassed &&
            contractHasEth &&
            hasPlayers &&
            isRaffleOpen;
        return (upkeepNeeded, "");
    }

    /**
     * @dev this function is called by chainlink automation to pick winner incase an upkeep is needed
     * @param - ignored
     */
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                block.timestamp - s_lastTimestamp,
                s_players.length,
                address(this).balance,
                s_raffleState
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RaffleRandomWordsRequested(requestId);
    }

    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] calldata randomWords
    ) internal override {
        // get the random words and then modulo it by 10, pick the winner using the values as index in the array and set a winner, transfer all funds to the winner.abi
        uint256 winnerIndex = randomWords[0] % 10;
        address winner = s_players[winnerIndex];
        s_winner = winner;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;

        emit WinnerPicked(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    // TODO: reset raffle state (incase fulfillRandomWords has failed executing)
    // 1. when its calculating
    // 2. contractHasEth
    // 3. interval * 5 hasPassed
    // 4. has players

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getIntervalFee() external view returns (uint256) {
        return i_interval;
    }

    function getKeyHash() external view returns (bytes32) {
        return i_keyHash;
    }

    function getSubId() external view returns (uint256) {
        return i_subId;
    }

    function getCallbackGasLimit() external view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getRafflePlayers(uint256 idx) external view returns (address) {
        return s_players[idx];
    }

    function getRafflePlayersLength() external view returns (uint256) {
        return s_players.length;
    }

    function getRaffleWinner() external view returns (address) {
        return s_winner;
    }
}
