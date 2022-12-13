// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./libraries/Block.sol";

contract CinemaTicket is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct TicketMetadata {
        uint256 totalCost;
        uint256 movieID;
    }

    Counters.Counter private tokenIDCounter;
    mapping(uint256 => TicketMetadata) public tokensMetadata;

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

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs|http://<CID|FOLDER>/"; // in progress
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
        uint256 currentTokenID = tokenIDCounter.current();

        _safeMint(_buyer, currentTokenID);
        _setApprovalForAll(_buyer, address(this), true);
        tokensMetadata[currentTokenID] = TicketMetadata(_totalPrice, _movieID);

        tokenIDCounter.increment();

        emit TicketIssued(_buyer, currentTokenID);
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
