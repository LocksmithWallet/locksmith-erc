// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {BadSessionAccount} from "../src/BadSessionAccount.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract BadSessionAccountTest is Test, ERC1155Holder {
    BadSessionAccount public account;

    function setUp() public {
        account = new BadSessionAccount();
    }

    function test_EnsureDeployerRootKey() public {
        assertEq(account.balanceOf(address(this), 0), 1);
    }
}
