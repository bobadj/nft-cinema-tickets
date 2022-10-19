// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./libraries/Block.sol";

contract CinemaTicket is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private tokenIDCounter;

    struct TicketMetadata {
        address buyer;
        uint256 totalSeats;
        uint256 totalCost;
        uint256 movieID;
    }

    mapping(uint256 => TicketMetadata) internal tokensMetadata;
    mapping(uint256 => mapping(address => uint256)) private movieToTokenOwnerMap;

    /*
    * Starts token counting from 1
    * Grants minter role for admin
    */
    constructor() ERC721 ("Cinema Ticket", "CIT") {
        tokenIDCounter.increment();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
    * Gets token metadata
    *
    * @param _tokenID - ID of particular token
    *
    * @return TicketMetadata struct with the specified _tokenID
    */
    function getTokenMetadata(uint256 _tokenID) public view returns(TicketMetadata memory) {
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
    function getTokenIdFromMovieAndAddress(uint256 _movieID, address _address) public view returns(uint256) {
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
                            '"image": "https://chart.googleapis.com/chart?chs=300x300&cht=qr&chl=https://testnets.opensea.io/assets/', Block.chainName(block.chainid) ,'/', abi.encodePacked(address(this)) ,'/', abi.encodePacked(tokenID) ,'&choe=UTF-8",',
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
    * @param _buyer - buyer address
    * @param _movieID - ID of movie ticket should be associated with
    * @param _seats - seats booked
    * @param _totalPrice - price payed
    * @param _movieTitle - title of a movie
    *
    * @notice contract should be an operator for minted token in order to burn it
    * after token is used or canceled
    * @notice should not be able to mint multiple tokens for the same movie,
    * force addresses to cancel the previous tickets and buy new ones
    *
    */
    function mint(address _buyer, uint256 _movieID, uint256 _seats, uint256 _totalPrice, string memory _movieTitle) onlyRole(MINTER_ROLE) public {
        require(_buyer != address(0), "Invalid buyer");
        require(!hasTokenAssociatedWithMovie(_movieID, _buyer), "You already have ticket for this this movie.");
        uint256 currentTokenID = tokenIDCounter.current();

        _safeMint(_buyer, currentTokenID);
        _setApprovalForAll(_buyer, address(this), true);
        _setTokenURI(currentTokenID, formatTokenURI(_movieTitle));
        movieToTokenOwnerMap[_movieID][_buyer] = currentTokenID;
        tokensMetadata[currentTokenID] = TicketMetadata(_buyer, _seats, _totalPrice, _movieID);

        tokenIDCounter.increment();
    }

    function burn(TicketMetadata memory _ticketMeta, uint256 _tokenId) onlyRole(MINTER_ROLE) public {
        require(_exists(_tokenId), "Token does not exists");
        address ticketHolder = ownerOf(_tokenId);
        require(_ticketMeta.buyer == ticketHolder, "Ticket holder and ticket buyer does not match");

        _burn(_tokenId);

        delete tokensMetadata[_tokenId];
        delete movieToTokenOwnerMap[_ticketMeta.movieID][_ticketMeta.buyer];
    }

    /*
    * Solidity requires
    */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
