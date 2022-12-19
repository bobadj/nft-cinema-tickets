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
    mapping(uint256 => TicketMetadata) public tokensMetadata;

    struct TicketMetadata {
        uint256 totalCost;
        uint256 movieID;
        bool checkedIn;
    }

    event TicketIssued(address indexed owner, uint256 tokenID);

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
    * Mints new token for msg.sender
    *
    * @param _buyer - buyer address
    * @param _movieID - ID of movie ticket should be associated with
    * @param _totalPrice - price payed
    * @param _tokenURI - token uri ( ipfs cid )
    *
    * @notice contract should be an operator for minted token in order to burn it
    * after token is used or canceled
    *
    */
    function mint(address _buyer, uint256 _movieID, uint256 _totalPrice, string memory _tokenURI) onlyRole(MINTER_ROLE) public {
        require(_buyer != address(0), "Invalid buyer");
        uint256 currentTokenID = tokenIDCounter.current();

        _safeMint(_buyer, currentTokenID);
        _setApprovalForAll(_buyer, address(this), true);
        _setTokenURI(currentTokenID, _tokenURI);
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
        ticketMeta.checkedIn = true;
        tokensMetadata[_tokenId] = ticketMeta;
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
    }

    /*
    * Solidity requires
    */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
