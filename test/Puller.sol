//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

///////////////////////////////////////////////////////////
// IMPORTS
//
// We are going to build a flexible and dumb ERC20 factory.
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
///////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////
// Puller 
//
// This contract simply pulls a specific ERC20 into the contract
// using the allowance.
///////////////////////////////////////////////////////////
contract Puller {
    address public target;

    constructor(address _target) {
        target = _target;
    }

    /**
     * pull 
     *
     * Pulls 1 ether worth of an ERC20 away from the message sender.
     * This "sort of" emulates calling Uniswap, without giving anything back.
     * It emulates it by relying on msg.sender allowances to utilize ERC20s.
     */
    function pull() public { 
        IERC20(target).transferFrom(msg.sender, address(this), 1 ether);
    }
}
