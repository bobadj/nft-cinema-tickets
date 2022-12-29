// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

contract CinemaTicket is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private tokenIDCounter;
    mapping(uint256 => string) public movieToTokenCID;
    mapping(uint256 => TicketMetadata) public tokensMetadata;

    struct TicketMetadata {
        uint256 totalCost;
        uint256 movieID;
        bool checkedIn;
    }

    event TicketIssued(address indexed owner, uint256 tokenID);
    event TicketCanceled(uint256 tokenID);
    event TicketCheckedIn(uint256 tokenID);

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

    /*
    * Assign token CID for movie
    *
    * @param _movieID - ID of movie
    * @param _tokenCID - ipfs CID
    *
    * @notice could be used only once per movieID, if mapping already exists, it can not be override
    * @notice available for MINTER_ROLE only
    *
    * no returns
    */
    function assignTokenCidToMovie(uint256 _movieID, string memory _tokenCID) onlyRole(MINTER_ROLE) public {
        require(bytes(_tokenCID).length > 0, "Invalid token CID");
        require(bytes(movieToTokenCID[_movieID]).length <= 0, "Token CID for movie is already assigned.");
        movieToTokenCID[_movieID] = _tokenCID;
    }

    /**
    * Mints new token for msg.sender
    *
    * @param _buyer - buyer address
    * @param _movieID - ID of movie ticket should be associated with
    * @param _totalPrice - price payed
    *
    * @notice contract should be an operator for minted token in order to burn it
    * after token is used or canceled
    *
    */
    function mint(address _buyer, uint256 _movieID, uint256 _totalPrice) onlyRole(MINTER_ROLE) public {
        require(_buyer != address(0), "Invalid buyer");
        string memory tokenURI = movieToTokenCID[_movieID];
        require(bytes(tokenURI).length > 0, "There is no ipfs CID for this movie.");
        uint256 currentTokenID = tokenIDCounter.current();

        _safeMint(_buyer, currentTokenID);
        _setApprovalForAll(_buyer, address(this), true);
        _setTokenURI(currentTokenID, tokenURI);
        tokensMetadata[currentTokenID] = TicketMetadata(_totalPrice, _movieID, false);

        tokenIDCounter.increment();

        emit TicketIssued(_buyer, currentTokenID);
    }

    /*
    * Mark token as check-in
    */
    function markAsCheckedIn(uint256 _tokenId) onlyRole(MINTER_ROLE) public {
        require(_exists(_tokenId), "Token does not exists");
        TicketMetadata memory ticketMeta = tokensMetadata[_tokenId];
        require(!ticketMeta.checkedIn, "Not able to check-in twice.");

        ticketMeta.checkedIn = true;
        tokensMetadata[_tokenId] = ticketMeta;

        emit TicketCheckedIn(_tokenId);
    }

    /**
    * Burns token and deletes tokens meta and owner mapping
    *
    * @param _tokenId - token ID
    *
    */
    function burn(uint256 _tokenId) onlyRole(MINTER_ROLE) public {
        require(_exists(_tokenId), "Token does not exists");

        _burn(_tokenId);

        delete tokensMetadata[_tokenId];

        emit TicketCanceled(_tokenId);
    }

    /*
    * Solidity requires
    */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
