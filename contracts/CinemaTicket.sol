// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import "./libraries/Block.sol";

abstract contract CinemaTicket is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIDCounter;

    struct TicketMetadata {
        address buyer;
        uint256 totalSeats;
        uint256 totalCost;
        uint256 movieID;
    }

    mapping(uint256 => TicketMetadata) internal tokensMetadata;
    mapping(uint256 => mapping(address => uint256)) private movieToTokenOwnerMap;

    modifier requireValidMovie(uint256 _movieID) virtual {
        _;
    }

    /*
    * Starts token counting from 1
    */
    constructor() ERC721 ("Cinema Ticket", "CIT") {
        tokenIDCounter.increment();
    }

    /**
    * Gets token metadata
    *
    * @param _tokenID - ID of particular token
    *
    * @return TicketMetadata struct with the specified _tokenID
    */
    function getTokenMetadata(uint256 _tokenID) internal view returns(TicketMetadata memory) {
        _requireMinted(_tokenID);
        return tokensMetadata[_tokenID];
    }

    /**
    * Gets tokenID for movie, based on address
    *
    * @param _movieID - ID of a movie
    * @param _address - address associated with ticket
    *
    * @return ID of a token
    */
    function getTokenIdFromMovieAndAddress(uint256 _movieID, address _address) requireValidMovie(_movieID) internal view returns(uint256) {
        require(_address != address(0), "Address is not valid.");
        require(movieToTokenOwnerMap[_movieID][_address] > 0, "There is no token associated with movie.");
        require(_exists(movieToTokenOwnerMap[_movieID][_address]), "Token is burned or never minted.");
        return movieToTokenOwnerMap[_movieID][_address];
    }

    /**
    * Determinate does address has token associated with movie
    *
    * @param _movieID - ID of movie
    * @param _address - address for lookup
    *
    * @return boolean
    */
    function hasTokenAssociatedWithMovie(uint256 _movieID, address _address) internal view returns(bool) {
        return movieToTokenOwnerMap[_movieID][_address] > 0 && _exists(movieToTokenOwnerMap[_movieID][_address]);
    }

    /**
    * Builds token uri
    *
    * @param _movieTitle - Title of a movie
    *
    * @return JSON encoded string
    */
    function formatTokenURI(string memory _movieTitle) private view returns (string memory) {
        uint256 tokenID = tokenIDCounter.current();
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{',
                            '"name": "Cinema Ticket",',
                            '"image": "https://chart.googleapis.com/chart?chs=300x300&cht=qr&chl=https://testnets.opensea.io/assets/', Block.chainName(block.chainid) ,'/', Strings.toHexString(uint160(address(this)), 20) ,'/', Strings.toString(tokenID) ,'&choe=UTF-8",',
                            '"attributes": [{ "trait_type": "Movie title", "value": "', _movieTitle ,'" }]',
                            '}'
                        )
                    )
                )
            )
        );
    }

    /**
    * Mints new token for msg.sender
    *
    * @param _movieID - ID of movie ticket should be associated with
    *
    * @notice contract should be an operator for minted token in order to burn it
    * after token is used or canceled
    * @notice should not be able to mint multiple tokens for the same movie,
    * force addresses to cancel the previous tickets and buy new ones
    *
    * @return ID of a token
    */
    function mint(uint256 _movieID, string memory _movieTitle) requireValidMovie(_movieID) internal returns(uint256) {
        require(!hasTokenAssociatedWithMovie(_movieID, msg.sender), "You already have ticket for this this movie.");
        uint256 currentTokenID = tokenIDCounter.current();

        _safeMint(msg.sender, currentTokenID);
        _setApprovalForAll(msg.sender, address(this), true);
        _setTokenURI(currentTokenID, formatTokenURI(_movieTitle));
        movieToTokenOwnerMap[_movieID][msg.sender] = currentTokenID;

        tokenIDCounter.increment();

        return currentTokenID;
    }

    /**
    * Updates mapping
    *
    * todo - after token transfer, will contract still be a operator?
    */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) override internal virtual {
        TicketMetadata memory ticketMeta = tokensMetadata[tokenId];
        movieToTokenOwnerMap[ticketMeta.movieID][to] = tokenId;
        ticketMeta.buyer = to;
        tokensMetadata[tokenId] = ticketMeta;
        delete movieToTokenOwnerMap[ticketMeta.movieID][from];
    }
}
