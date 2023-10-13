// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.21;

// The Locksmith contract should also be a generic ERC1155 token
// underneath for minting, burning, and transfer mechanics.
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155.sol";

/**
 * IKeyLocksmith
 *
 *
 */
interface IKeyLocksmith is IERC1155 {
    ///////////////////////////////////////////////////////
    // Events
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
     * getHolders
     *
     * This method will return the addresses that hold
     * a particular keyId
     *
     * @param keyId the key ID to look for
     * @return an array of addresses that hold that key
     */
    function getHolders(uint256 keyId) external view returns (address[] memory); 
    
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
    // Only the anointed locksmith can call these. 
    ////////////////////////////////////////////////////////

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
    function soulbind(adress keyHolder, uint256 keyId, uint256 amount) external; 

    /**
     * burn 
     *
     * The caller must be the locksmith, or can only burn their own keys.
     * If the message sender is also the holder, they are capable of burning
     * their own soulbound keys. This prevents address griefing.
     *
     * @param holder     the address of the key holder you want to burn from
     * @param keyId      the ERC1155 NFT ID you want to burn
     * @param burnAmount the number of said keys you want to burn from the holder's possession.
     */
    function burn(address holder, uint256 keyId, uint256 burnAmount) external;    
}