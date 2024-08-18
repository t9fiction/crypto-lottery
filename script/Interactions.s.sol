// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    function createSubsriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address _vrfCoordinator
    ) public returns (uint256, address) {
        console.log("Creating subscription on ChainId", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("Your Subscription Id : ", subId);
        console.log(
            "Please update your Subscription Id in HelperConfig.s.sol file"
        );
        return (subId, _vrfCoordinator);
    }

    function run() public {
        createSubsriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // Will be 3 Link

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        /**
         **  Since the Subscription ID is updated in the above contract, so we can use it.
         */
        uint256 subcriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;

        /**
         ** Funding the subscription, since we have all three values now.
         */
        fundSubscription(vrfCoordinator, subcriptionId, linkToken);
    }

    function fundSubscription(
        address _vrfCoordinator,
        uint256 _subscriptionId,
        address _linkToken
    ) public {
        console.log("Funding Subscription ....", _subscriptionId);
        console.log("Using VRF Coordinator....", _vrfCoordinator);
        console.log("On chain Id ...", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(
                _subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(_linkToken).transferAndCall(
                _vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {

    function addConsumerUsingConfig(address _mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        addConsumer(_mostRecentlyDeployed, vrfCoordinator, subscriptionId);
    }

    function addConsumer(address _contractToAddToVRF, address _vrfCoordinator, uint256 _subId) public {
        console.log("Adding consumer contract: ", _contractToAddToVRF);
        console.log("To vrfCoordinator ",_vrfCoordinator);
        console.log("on ChainId : ",block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(_subId, _contractToAddToVRF);
        vm.stopBroadcast();
    }
    
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }

}
