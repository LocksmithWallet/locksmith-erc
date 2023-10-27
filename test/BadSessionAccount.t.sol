// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {
    BadSessionAccount,
    ExistingSession,
    InsufficientAllowance,
    Unauthorized,
    UnauthorizedDestination
} from "../src/BadSessionAccount.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
using EnumerableSet for EnumerableSet.AddressSet;

contract BadSessionAccountTest is Test, ERC1155Holder {
    BadSessionAccount public account;
    string public constant mnemonic = "test test test test test test test test test test test junk"; 

    address public second;

    address[] public emptyDestinations;
    EnumerableSet.AddressSet private destinations;

    receive() external payable { 
        // needed to be able to take money
    }

    function setUp() public {
        // create the account
        account = new BadSessionAccount();
        
        // prepare a second operator in case we need to prank
        second = vm.addr(vm.deriveKey(mnemonic, 0));

        // fund this test, and the account
        vm.deal(address(this), 10 ether);
        (bool success,) = address(account).call{value: 1 ether}("");
        assert(success);

        // generate some test data
        destinations.add(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        destinations.add(0x4E5d95F1D3d1b1FB4a169554A6bff1fD164ACa2c);
        destinations.add(0xB617dFa5Cf63C55F5E3f351A70488cE34EDcc9C6);
    }

    function test_EnsureDeployerRootKey() public {
        assertEq(account.balanceOf(address(this), 0), 1);
    }

    function test_CreateKeyRequiresRoot() public {
        account.safeTransferFrom(address(this), second, 0, 1, '');
        assertEq(account.balanceOf(address(this), 0), 0);
        vm.expectRevert(Unauthorized.selector);
        account.createKey(0, second);
    }

    function test_CreateSuccessWithRoot() public {
        account.createKey(1, second);
        assertEq(account.balanceOf(second, 1), 1);
    }

    function test_BurnKeyRequiresRoot() public {
        account.createKey(1, second);
        account.safeTransferFrom(address(this), second, 0, 1, '');
        assertEq(account.balanceOf(address(this), 0), 0);
        vm.expectRevert(Unauthorized.selector);
        account.burnKey(second, 1, 1);
    }

    function test_CantBurnMissingKey() public {
        vm.expectRevert();
        account.burnKey(second, 1, 1);
    }

    function test_CanBurnExistingKey() public {
        account.createKey(1, second);
        assertEq(account.balanceOf(second, 1), 1);
        account.burnKey(second, 1, 1);
        assertEq(account.balanceOf(second, 1), 0);
    }

    function test_CreateSessionRequiresRoot() public {
        account.createKey(1, second);
        account.safeTransferFrom(address(this), second, 0, 1, '');
        assertEq(account.balanceOf(address(this), 0), 0);
        vm.expectRevert(Unauthorized.selector);
        account.createSession(1, destinations.values(), 1);
    }

    function test_CantDuplicateSessionCreation() public {
        account.createKey(1, second);
        account.createSession(1, destinations.values(), 1);
        vm.expectRevert(ExistingSession.selector);
        account.createSession(1, emptyDestinations, 5);
    }

    function test_CanDepositMoney() public {
        assertEq(address(account).balance, 1 ether);
        (bool success,) = address(account).call{value: 1 ether}("");
        assert(success);
        assertEq(address(account).balance, 2 ether);
    }

    function test_CantOperateAccountWithoutRoot() public {
        account.safeTransferFrom(address(this), second, 0, 1, '');
        assertEq(account.balanceOf(address(this), 0), 0);
        vm.expectRevert(Unauthorized.selector);
        account.execute(0, second, 1 ether, '');
    }

    function test_CanOperateWithRoot() public {
        assertEq(address(this).balance, 9 ether);
        assertEq(address(account).balance, 1 ether);
        account.execute(0, address(this), 1 ether, '');
        assertEq(address(this).balance, 10 ether);
        assertEq(address(account).balance, 0 ether);
    }

    function test_SessionRequiresKey() public {
        account.createKey(1, second);
        account.createSession(1, destinations.values(), 1);
        vm.expectRevert(Unauthorized.selector);
        // we don't actually hold keyId 1
        account.execute(1, destinations.values()[0], 1 ether, '');
    }

    function test_SessionMustBeValid() public {
        account.createKey(1, second);
        account.createSession(1, destinations.values(), 1);
        vm.expectRevert(Unauthorized.selector);
        account.execute(5, destinations.values()[0], 1 ether, '');
    }

    function test_SessionBlocksBadDestinations() public {
        account.createKey(1, address(this));
        account.createSession(1, destinations.values(), 1);
        vm.expectRevert(UnauthorizedDestination.selector);
        account.execute(1, 0xD44fe4cd5C0A3312E76514ff43BDd05826D3AF5B, 1 ether, '');
    }

    function test_CantSpendMoreThanAllowance() public {
        account.createKey(1, address(this));
        account.createSession(1, destinations.values(), 1);
        vm.expectRevert(InsufficientAllowance.selector);
        account.execute(1, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 1 ether, '');

        // now just spend the measly amount
        account.execute(1, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 1, '');

        // and overdraft again
        vm.expectRevert(InsufficientAllowance.selector);
        account.execute(1, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 1, '');
    }
}
