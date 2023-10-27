// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
contract Shadow721 is ERC721 {
    constructor() ERC721('ShadowNFT', 'SNFT') {}
    function safeMint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }
}
