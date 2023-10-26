// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.21;

// The session contract should also be a generic ERC1155 token
// underneath for minting, burning, and transfer mechanics.
import "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
using EnumerableSet for EnumerableSet.AddressSet;

/**
 * ISessionManager
 *
 * A purposefully flawed interface for a session model 
 * for a smart contract account.
 */
interface ISessionManager {
    /**
     * createSession 
     *
     * Interface for creating a session. This will provide some level of
     * permission to this NFT holder for account assets.
     *
     * @param keyId           the nft ID that defines the session holder
     * @param destinations    the list of destination addresses that are valid for this session
     * @param totalValue      the total amount of ether that can be used in this session
     * @param tokens          the list of tokens we want to maintain balances for
     * @param tokenAllowance  the list of token allowances per listed token address
     */
    function createSession(
        address keyId,
        address[] destinations, 
        uint256 totalValue,
        address[] tokens,
        uint256[] tokenAllowances) external;
}
