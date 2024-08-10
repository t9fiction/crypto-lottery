// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 **
 */
contract Raffle {
    /** Custom Errors */
    error NotEnoughEthSent();

    uint256 private immutable i_entranceFee;

    constructor(uint256 _entranceFee) {
        i_entranceFee = _entranceFee;
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee,"Not enough Eth sent!");
        // require(msg.value >= i_entranceFee, NotEnoughEthSent());
        if (msg.value < i_entranceFee) {
            revert NotEnoughEthSent();
        }
    }
    function pickWinner() public {}

    /** Getter Functions */

    function getEntranceFees() public view returns (uint256) {
        return i_entranceFee;
    }
}
