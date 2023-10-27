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
import { ShadowERC } from 'test/ShadowERC.sol';
import { Shadow721 } from 'test/Shadow721.sol';
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
using EnumerableSet for EnumerableSet.AddressSet;

contract CodeCoverageTest is Test, ERC1155Holder {
    BadSessionAccount public account;
    ShadowERC public erc20; 
    Shadow721 public erc721;

    string public constant mnemonic = "test test test test test test test test test test test junk"; 

    address public second;

    address[] public emptyDestinations;
    EnumerableSet.AddressSet private destinations;
    EnumerableSet.AddressSet private onlyERC20;

    receive() external payable { 
        // needed to be able to take money
    }

    function setUp() public {
        // create the account
        account = new BadSessionAccount();
       
        // create the tokens
        erc20 = new ShadowERC('Link', 'LINK');
        erc20.spawn(1 ether);
        erc721 = new Shadow721();

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
        onlyERC20.add(address(erc20));
    }

    function test_DepositTokensAndSendAsRoot() public {
        // deposit the money
        assertEq(erc20.balanceOf(address(this)), 1 ether);
        erc20.transfer(address(account), 1 ether);
        assertEq(erc20.balanceOf(address(account)), 1 ether);
        assertEq(erc20.balanceOf(address(this)), 0 ether);
        assertEq(erc20.balanceOf(address(second)), 0 ether);

        // use the root key to send it to second
        account.execute(0, address(erc20), 0, 
            abi.encodeWithSelector(erc20.transfer.selector, second, 1 ether));
       
        assertEq(erc20.balanceOf(address(account)), 0 ether);
        assertEq(erc20.balanceOf(address(this)), 0 ether);
        assertEq(erc20.balanceOf(address(second)), 1 ether);
    }

    function test_Deposit721AndSendAsRoot() public {
        // mint nft 
        erc721.safeMint(address(account), 1);
        assertEq(erc721.ownerOf(1), address(account));

        // use the root key to send it to second
        account.execute(0, address(erc721), 0,
            abi.encodeWithSelector(erc721.transferFrom.selector, address(account), second, 1));

        // did it move properly?
        assertEq(erc721.ownerOf(1), address(second));
    }

    function test_DepositTokensCantSendWithoutRoot() public {
        erc20.transfer(address(account), 1 ether);

        // send the root key away
        account.safeTransferFrom(address(this), second, 0, 1, '');
      
        // we expect the send to fail for authorization
        vm.expectRevert(Unauthorized.selector);

        // attempt to send
        account.execute(0, address(erc20), 0,
            abi.encodeWithSelector(erc20.transfer.selector, second, 1 ether));
    }

    function test_Deposit721CantSendWithoutRoot() public {
        // mint nft into account
        erc721.safeMint(address(account), 1);
        
        // send away root
        account.safeTransferFrom(address(this), second, 0, 1, '');

        // try to send NFT but will fail
        vm.expectRevert(Unauthorized.selector);

        // caller doesn't hold root key
        account.execute(0, address(erc721), 0,
            abi.encodeWithSelector(erc721.transferFrom.selector, address(account), second, 1));
    }

    function test_DepositTokensSessionCantSend() public {
        // create a session that doesn't have erc20 access
        account.createKey(1, address(this));
        account.createSession(1, destinations.values(), 0);
        
        // we expect the send to fail for authorization
        vm.expectRevert(UnauthorizedDestination.selector);
        
        // attempt to send
        account.execute(1, address(erc20), 0,
            abi.encodeWithSelector(erc20.transfer.selector, second, 1 ether));
    }

    function test_Deposit721SessionCantSend() public {

    }

    function test_DepositTokensSessionCanSend() public {
        erc20.transfer(address(account), 1 ether);
        assertEq(erc20.balanceOf(second), 0 ether);
        assertEq(erc20.balanceOf(address(account)), 1 ether);
        account.createKey(1, address(this));
        account.createSession(1, onlyERC20.values(), 0);
        account.execute(1, address(erc20), 0,
            abi.encodeWithSelector(erc20.transfer.selector, second, 1 ether));
        assertEq(erc20.balanceOf(second), 1 ether);
        assertEq(erc20.balanceOf(address(account)), 0 ether);
    }
}
