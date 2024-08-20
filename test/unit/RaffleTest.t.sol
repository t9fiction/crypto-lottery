// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); //Makes some player enter the raffle

        /** Wait for 30 secs for the upkeep to start working.
         ***  This will take the timestamp to the time interval we set for upkeep
         */
        vm.warp(block.timestamp + interval + 1);
        /**
         ** We are now going to manually move the block to next block
         */
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); // Giving enough balance for player to test transactions
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitEvents() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); //Makes some player enter the raffle

        /** Wait for 30 secs for the upkeep to start working.
         ***  This will take the timestamp to the time interval we set for upkeep
         */
        vm.warp(block.timestamp + interval + 1);
        /**
         ** We are now going to manually move the block to next block
         */
        vm.roll(block.number + 1);
        /** Set to Close
         *** By calling perform upkeep, since it changes it to close
         **/
        raffle.performUpkeep();
        /**
         *** Try entering Raffle
         */
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //Expecting Revert while Raffle is calculating
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        /** Wait for 30 secs for the upkeep to start working.
         ***  This will take the timestamp to the time interval we set for upkeep
         */
        vm.warp(block.timestamp + interval + 1);
        /**
         ** We are now going to manually move the block to next block
         */
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public raffleEntered {
        
        /** Set to Close
         *** By calling perform upkeep, since it changes it to close
         **/
        raffle.performUpkeep();
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepOnlyRunsIfCheckUpkeepIsTrue() public raffleEntered{
        
        /** Set to Close
         *** By calling perform upkeep, since it changes it to close
         **/
        raffle.performUpkeep();
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep();
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered{
        
        /** Cheatcode to check events by factory,
         ** Following will record logs, and then save the recordedlogs to entries of Vm array
         */
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }
}
