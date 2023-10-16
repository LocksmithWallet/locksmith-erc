// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.21;

/**
 * IKeyAccount 
 *
 *
 */
interface IKeyAccount { 
    /**
     * locksmith
     *
     * This methods returns the destination contract that
     * owns this key account. The locksmith is determined
     * by both a destination chain, and the contract address.
     * It is assumed that only keyId zero can modify this
     * account.
     *
     * @return chainId   the ID of the chain of the locksmith contract
     * @return locksmith the address of the NFT token contract that operates this account
     */
    function locksmith() external view returns (
        uint256 chainId,
        address locksmith
    );

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
     * nonce
     *
     * For smart accounts these may not matter, but for
     * compatibility it may be important to understand
     * the "nonce" of a given account, especially in circumstances
     * where you are treating this transparently like
     * an EOA, even though this account wont require
     * signatures.
     *
     * @return the virtual nonce of the account
     */
    function nonce() external view returns (uint256);

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
     * @param operation   (0: call, 1: delegatecall, 2: create, 3: create2)
     * @param data        the actual serialized method bytes and parameters
     * @return the raw memory of the method's response. this will need deserialization.
     */
    function execute(
        uint256 keyId,
        address destination,
        uint256 value, 
        uint256 operation,
        bytes calldata data
    ) external payable returns (bytes memory);
}
