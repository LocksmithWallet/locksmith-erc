// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import "interfaces/ISimpleSessionAccount.sol";
import "interfaces/ISessionManager.sol";

import "@openzeppeli-contracts/contracts/utils/structs/EnumerableSet.sol";
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
        bool valid;                                   // ensure a valid mapping
        
        uint256 etherAllowance;                       // total remaining ether allowance
        EnumerableSet.AddressSet allowedDestinations; // only these addresses can be called
        
        EnumerableSet.AddressSet monitoredTokens;     // a list of tokens we want to monitor
        mapping(address => uint256) tokenAllowances;  // the mapping of total allowances for those tokens
        
        EnumerableSet.AddressSet monitoredNFTs;                         // a list of NFTs we want to monitor
        mapping(address => EnumerableSet.UintSet) monitoredIds;         // a list of ids to monitor per collection
        mapping(address => mapping(uint256 => uint256)) nftAllowances;  // contract => tokenId => allowance 
 
        EnumerableSet.Bytes32Set nftHashes;    // storage buffer used to keep temporary NFT/ID hashes
        mapping(bytes32 => uint256) nftBuffer; // storage that is used to keep temporary NFT/ID => balance mappings
    }
    
    ////////////////////////////////////////////////////////
    // Storage
    ////////////////////////////////////////////////////////
    // each unique key can only have one session
    mapping(uint256 => Session) keySessions;

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
     * @param tokens          the list of tokens we want to maintain balances for
     * @param tokenAllowance  the list of token allowances per listed token address
     * @param nfts            the list of nfts we want to maintain balances for
     * @param nftIds          the list of nfts token IDs per listed token address
     * @param nftAllowance    the list of nft id allowances
     * @return
     */
    function createSession(
        address keyId,
        address[] destinations,
        uint256 totalValue,
        address[] tokens,
        uint256[] tokenAllowances,
        address[] nfts,
        uint256[] nftIds,
        uint256[] nftAllowance) external onlyLocksmith {

        // for simplicity sake, let's assume you can't overwrite a session
        if (keySessions[keyId].valid) {
            revert ExistingSession(); 
        }

        // make sure the dimensions of the input is sane
        if ((tokens.length != tokenAllowances.length) ||
            (nfts.length != nftIds.length) || (nfts.length != nftAllowance.length) ) {
            return BadInput();
        }

        // store the session
        Session storage s = keySessions[keyId];
        s.valid = true
        s.etherAllowance = totalValue;
        for (uint256 x = 0; x < destinations.length; x++) {
            s.allowedDestinations.add(destinations[x]);
        }
        for (uint256 y = 0; y < tokens.length; y++) {
            s.monitoredTokens.add(tokens[y]);
            s.tokenAllowances[tokens[y]] = tokenAllowances[y];
        }
        for (uint256 z = 0; z < nfts.length; z++) {
            s.monitoredNFTs.add(nfts[z]);
            s.monitoredIds[nfts[z]].add(nftIds[z]);
            s.nftAllowances[nfts[z]][nftIds[z]] = nftAllowance[z];
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
     * @param value       the amount of ether/gas you want to send as part of this transaciton
     * @param data        the actual serialized method bytes and parameters
     * @return the raw memory of the method's response. this will need deserialization.
     */
    function execute(
        uint256 keyId,
        address destination,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        // fail if the caller isn't holding the declared key 
        if (balanceOf(msg.sender, keyId) < 1) {
            revert Unauthorized();
        }

        if (0 == keyId) {
            (bool success, bytes memory resp) = payable(destination).call{value: value}(data);
            assert(success);
            return resp;
        }

        // attempt to get the valid session and 
        // fail if there is no valid session for the key
        Session storage s = keySessions[keyId];
        if (!s.valid) {
            revert Unauthorized();
        }
   
        // we have a valid non-root session. check
        // to see if there is any destination restrictions.
        // an empty list semantically acts as no restrictions
        if (s.allowedDestinations.length() != 0 && !s.allowedDestinations.contains(destination)) {
            revert UnauthorizedDestination();
        }

        // check to see that the value doesn't overspend
        if (s.etherAllowance < value) {
            revert InsufficientAllowance();        
        }

        // collect the initial token balances 
        uint256 memory tokenBalances[] = new uint256[](s.monitoredTokens.length());
        address memory tokenAddresses[] = s.monitoredTokens.values(); 
        for (uint256 x = 0; x < tokenBalances.length; x++) {
            tokenBalances[x] = IERC20(tokenAddresses[x]).balanceOf(address(this));
        }

        // collect the initial NFT Balances
        address memory nftAddresses[] = s.monitoredNFTs.values();
        for(uint256 x = 0; x < nftAddresses.length; x++) {
            uint256[] memory ids = monitoredIds[nftAddresses[x]].values();
       
            for(uint256 y = 0; y < ids.length; y++) {
                // generate and store the hashes, as well as get the balance
                bytes32 hash = keccak256(abi.encode(nftAddresses[x], ids[y]));
            }
        }

        // do the actual thing
        (bool success, bytes memory resp) = payable(destination).call{value: value}(data);

        // double check the resulting token balances 
        for(uint256 x = 0; x < tokenBalances.length; x++) {
            uint256 newBalance = IERC20(tokenAddresses[x]).balanceOf(address(this));

            // if the balance hasn't changed or gone up, no allowance is used 
            if (tokenBalances[x] <= newBalance) {
                continue;
            }

            // if the new balance for this token is now less,
            // and the difference is bigger than the allowance, error
            if(tokenBalances[x] - newBalance > s.tokenAllowances[tokenAddresses[x]]) {
                revert InsufficientAllowance();
            } else {
                // at this point, simply reduce the allowance
                s.tokenAllowances[tokenAddresses[x]] -= (tokenBalances[x] - newBalance);
            }
        }
    }
}
