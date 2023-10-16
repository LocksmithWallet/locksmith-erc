// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.21;

// The Locksmith contract should also be a generic ERC1155 token
// underneath for minting, burning, and transfer mechanics.
import "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";

/**
 * IKeyLocksmith
 *
 *
 */
interface IKeyLocksmith is IERC1155 {
    ///////////////////////////////////////////////////////
    // Events
    //
    // For mint, burn, and transfers, we leverage the existing
    // ERC1155 event pattern.
    ///////////////////////////////////////////////////////
    
    /**
     * setSoulboundKeyAmount 
     *
     * This event fires when the state of a soulbind key is set.
     *
     * @param operator  the person making the change, should be the locksmith
     * @param keyHolder the 'soul' we are changing the binding for
     * @param keyId     the Id we are setting the binding state for
     * @param amount    the number of tokens this person must hold
     */
    event setSoulboundKeyAmount(address operator, address keyHolder, 
        uint256 keyId, uint256 amount); 

    ////////////////////////////////////////////////////////
    // Introspection
    ////////////////////////////////////////////////////////

    /**
     * name
     *
     * @return the name of the collection
     */
    function name() external returns (string memory);

    /**
     * getKeyCount()
     *
     * This evil bytecode is necessary to return a list of keys
     * that have been minted and have an active balance. 
     *
     * @return the number of keys in the collection 
     */
    function getKeyCount() external view returns (uint256);

    /**
     * getKeys
     *
     * This method will return the IDs of the keys held
     * by the given address.
     *
     * @param holder the address of the key holder you want to see
     * @return an array of key IDs held by the user.
     */
    function getKeys(address holder) external view returns (uint256[] memory); 

    /**
     * getKeyHolders
     *
     * This method will return the addresses that hold
     * a particular keyId
     *
     * @param keyId the key ID to look for
     * @return an array of addresses that hold that key
     */
    function getKeyHolders(uint256 keyId) external view returns (address[] memory); 
    
    /**
     * keyBalanceOf 
     *
     * Get either the key balance, or the soulbound requirement.
     *
     * @param account   the wallet address you want the balance for
     * @param id        the key Id you want the balance of.
     * @param soulbound true if you want the soulbound balance
     * @return the token balance for that wallet and key id
     */
    function keyBalanceOf(address account, uint256 id, bool soulbound) external view returns (uint256);

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
     * By default this key will not have any account sessions
     * attached to them.
     *
     * @param keyName   an alias that you want to give the key
     * @param uri       the URI of the token with associated metadata
     * @param receiver  address you want to receive an NFT key for the trust
     * @param bind      true if you want to bind the key to the receiver
     * @return the ID of the key that was created
     */
    function createKey(bytes32 keyName, string uri, address receiver, bool bind) external returns (uint256);
    
    /**
     * copyKey
     *
     * The root key holder can call this method if they have an existing key
     * they want to copy. This allows multiple people to fulfill the same role,
     * share a set of sessions, or enables the root key holder to restore
     * the role for someone who lost their seed or access to their wallet.
     *
     * This method can only be invoked with a root key, which is held by
     * the message sender.
     *
     * This method will revert if the key isn't valid.
     *
     * @param keyId     key ID the message sender wishes to copy
     * @param receiver  addresses of the receivers for the copied key.
     * @param bind      true if you want to bind the key to the receiver
     */
    function copyKey(uint256 rootKeyId, uint256 keyId, address receiver, bool bind) external;

    /**
     * soulbind
     *
     * The locksmith can call this method to ensure that the current
     * key-holder at a specific address cannot exchange or move a certain
     * amount of keys from their wallets. Essentially it will prevent
     * transfers.
     *
     * It is safest to soulbind in the same transaction as the minting.
     * This function does not check if the keyholder holds the amount of
     * tokens. And this function is SETTING the soulbound amount. It is
     * not additive.
     *
     * @param keyHolder the current key-holder
     * @param keyId     the key id to bind to the keyHolder
     * @param amount    it could be multiple depending on the use case
     */
    function soulbind(address keyHolder, uint256 keyId, uint256 amount) external; 

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
}
