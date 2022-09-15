// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

contract CinemaTicket is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenID;

    event TicketIssued(address buyer, uint256 movieID);

    constructor() ERC721 ("Cinema Ticket", "CIT") {}

    /**
    * Builds token uri
    *
    * @return JSON encoded string
    */
    function formatTokenURI() private view returns (string memory) {
        return "tokenURI";
    }

    /**
    * Mints new token for msg.sender
    *
    * @param _movieID - ID of movie ticket should be associated with
    *
    * @return ID of and token
    */
    function mint(uint256 _movieID) public returns(uint256) {
        return 0;
    }

    /**
    * Burns a token
    *
    * no returns
    */
    function burn(uint256 _tokenID) public {}
}
