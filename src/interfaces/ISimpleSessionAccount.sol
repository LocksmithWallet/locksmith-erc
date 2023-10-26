// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.21;

// The session contract should also be a generic ERC1155 token
// underneath for minting, burning, and transfer mechanics.
import "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";

/**
 * ISimpleSessionAccount 
 *
 * A pared down version of ISessionAccount. 
 */
interface ISimpleSessionAccount is IERC1155 {
    ////////////////////////////////////////////////////////
    // Locksmith methods 
    //
    // Only the anointed locksmith can call these, which
    // will be any holder of the 0 keyId.
    ////////////////////////////////////////////////////////
    
    /**
     * createKey
     *
     * The holder of a root key can use it to generate brand new keys
     * and add them to the root key's associated trust, sending it to the
     * destination wallets.
     *
     * This method, in batch, will mint and send 1 new ERC1155 key
     * to each of the provided addresses.
     *
     * @param keyId     the Id of the key you want to create
     * @param receiver  address you want to receive an NFT key for the trust
     */
    function createKey(uint256 keyId, address receiver) external;
   
    /**
     * burnKey
     *
     * The caller must be the locksmith, or can only burn their own keys.
     * If the message sender is also the holder, they are capable of burning
     * their own soulbound keys. This prevents address griefing.
     *
     * @param holder     the address of the key holder you want to burn from
     * @param keyId      the ERC1155 NFT ID you want to burn
     * @param burnAmount the number of said keys you want to burn from the holder's possession.
     */
    function burnKey(address holder, uint256 keyId, uint256 burnAmount) external;    
    
    ////////////////////////////////////////////////////////
    // Account Interface Methods
    //
    //
    // These methods articulate what interface is available
    // in terms of the contract acting as an on-chain account.
    ////////////////////////////////////////////////////////

    /**
     * receive
     *
     * This enables the account to receive gas tokens.
     *
     * Ensuring this function enables the ability for accounts
     * to modify the behavior of receiving funds.
     */
    receive() external payable;

    /**
     * execute
     *
     * Executes instructions from within the context of the account.
     * This method requires authorization, which will be a combination
     * of the message sender, which keyId they declare to be using/holding,
     * and the internal state of the account.
     *
     * The declared key must be held by the user, as defined by the
     * associated locksmith contract.
     *
     * This method, when executed, could set token approvals, or move funds.
     * It is important to only allow authorized callers to exercise this.
     *
     * @param keyId       the key ID the message sender is declaring to use
     * @param destination the target address for the operation
     * @param value       the amount of ether/gas you want to send as part of this transaciton
     * @param data        the actual serialized method bytes and parameters
     * @return the raw memory of the method's response. this will need deserialization.
     */
    function execute(
        uint256 keyId,
        address destination,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory);
}
