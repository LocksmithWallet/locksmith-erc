// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import "src/interfaces/ISimpleSessionAccount.sol";
import "src/interfaces/ISessionManager.sol";

import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
using EnumerableSet for EnumerableSet.AddressSet;
using EnumerableSet for EnumerableSet.UintSet;

error Unauthorized();
error ExistingSession();
error BadInput();

error UnauthorizedDestination();
error InsufficientAllowance();

/**
 * BadSessionAccount 
 *
 * An intentionally poor implemenation of using sessions to segment
 * an account using sessions.
 */
contract BadSessionAccount is ISimpleSessionAccount, ISessionManager, ERC1155, ERC1155Holder, ERC721Holder {
    ////////////////////////////////////////////////////////
    // Data Structures
    ////////////////////////////////////////////////////////
    struct Session {
        bool valid;             // ensure a valid mapping
        uint256 etherAllowance; // total remaining ether allowance
        
        // these destinations determine what contracts can be interacted with.
        // this acts as an application and asset allow list. If the list is empty
        // we can assume that there are no restrictions. Access to assets is binary -
        // either you can interact with it (and use all the assets, potentially)
        // or you can't interact with it at all (and not set allowances, transfer,
        // or do anything meaningful).
        EnumerableSet.AddressSet allowedDestinations;
    }
    
    ////////////////////////////////////////////////////////
    // Storage
    ////////////////////////////////////////////////////////
    // each unique key can only have one session
    mapping(uint256 => Session) keySessions;

    constructor() ERC1155('') {
        // give a root key to the deployer
        _mint(msg.sender, 0, 1, '');
    }

    ////////////////////////////////////////////////////////
    // Locksmith methods 
    //
    // Only the anointed locksmith can call these, which
    // will be any holder of the 0 keyId.
    ////////////////////////////////////////////////////////
  
    modifier onlyLocksmith {
        if (balanceOf(msg.sender, 0) < 1) {
            revert Unauthorized(); 
        }

        _;
    }

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
    function createKey(uint256 keyId, address receiver) external onlyLocksmith {
        _mint(receiver, keyId, 1, ''); 
    }

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
    function burnKey(address holder, uint256 keyId, uint256 burnAmount) external onlyLocksmith {
        _burn(holder, keyId, burnAmount);
    }

    /**
     * createSession
     *
     * Interface for creating a session. This will provide some level of
     * permission to this NFT holder for account assets.
     *
     * @param keyId           the nft ID that defines the session holder
     * @param destinations    the list of destination addresses that are valid for this session
     * @param totalValue      the total amount of ether that can be used in this session
     */
    function createSession(uint256 keyId, address[] memory destinations, uint256 totalValue) external onlyLocksmith {
        // for simplicity sake, let's assume you can't overwrite a session
        if (keySessions[keyId].valid) {
            revert ExistingSession(); 
        }

        // store the session
        Session storage s = keySessions[keyId];
        s.valid = true;
        s.etherAllowance = totalValue;
        for (uint256 x = 0; x < destinations.length; x++) {
            s.allowedDestinations.add(destinations[x]);
        }
    }
    
    ////////////////////////////////////////////////////////
    // Account Interface Methods
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
    receive() external payable {
        // thanks bro!
    }

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
     * @param msgValue    the amount of ether/gas you want to send as part of this transaciton
     * @param data        the actual serialized method bytes and parameters
     * @return the raw memory of the method's response. this will need deserialization.
     */
    function execute(
        uint256 keyId,
        address destination,
        uint256 msgValue,
        bytes calldata data
    ) external returns (bytes memory) {
        // fail if the caller isn't holding the declared key 
        if (balanceOf(msg.sender, keyId) < 1) {
            revert Unauthorized();
        }

        // now: the msg.sender holds the declared ke
        // if the declared key is the master key, execute quickly
        // without any restrictions and exit immediately
        if (0 == keyId) {
            (bool success, bytes memory resp) = payable(destination).call{value: msgValue}(data);
            assert(success);
            return resp;
        }

        // if not root, attempt to find a valid session
        Session storage s = keySessions[keyId];
        if (!s.valid) {
            revert Unauthorized();
        }
   
        // now: we have a valid non-root session.
        // check for any relevant destination restrictions.
        // note: an empty list semantically acts as no restrictions
        if (s.allowedDestinations.length() != 0 && !s.allowedDestinations.contains(destination)) {
            revert UnauthorizedDestination();
        }

        // ensure the requested value doesn't overspend
        if (s.etherAllowance < msgValue) {
            revert InsufficientAllowance();        
        }

        // this won't underflow, so store the new
        // allowance
        s.etherAllowance -= msgValue;

        // do the actual thing
        // warning: this is re-entrant!
        (bool returnCode, bytes memory response) = payable(destination).call{value: msgValue}(data);
        assert(returnCode);
        return response;
    }

    /**
     * supportsInterface
     *
     * We need a custom implementation here
     * because we are both an ERC1155, and can hold NFTs as well.
     *
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC1155, ERC1155Holder) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
