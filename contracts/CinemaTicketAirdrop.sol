// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CinemaTicket.sol";

/**
  Ref: https://github.com/Uniswap/merkle-distributor
 */
contract CinemaTicketAirdrop is Ownable {
    address public immutable cinemaTicketAddress;

    struct Airdrop {
        bytes32 merkleRoot;
        uint256 startAt;
        uint256 endAt;
    }

    mapping(uint256 => Airdrop) private availableAirdrops;
    mapping(uint256 => mapping(address => bool)) private addressesClaimed;

    modifier requireValidAirdrop(uint256 _movieID) {
        require(availableAirdrops[_movieID].startAt > 0, "Airdrop for desired movie do not exist!");
        require(availableAirdrops[_movieID].startAt <= block.timestamp, "Airdrop has not started yet.");
        require(availableAirdrops[_movieID].endAt > block.timestamp, "Airdrop has expired.");
        _;
    }

    event AirdropMovieCreated(uint256 movieID, uint256 _startAt, uint256 _endAt);
    event Claimed(address account, uint256 movieID);

    /*
    * Save ERC721 token address
    *
    * @param _cinemaTicketAddress - ERC721 ( CinemaTicket ) address
    *
    */
    constructor(address _cinemaTicketAddress) {
        cinemaTicketAddress = _cinemaTicketAddress;
    }

    /*
    * Add new airdrop for movie
    *
    * @param _movieID - ID of an movie
    * @param _merkleRoot - whitelisted addresses as merkle root
    * @param _startAt - timestamp when Airdrop should start
    * @param _endAt - timestamp when Airdrop should end
    *
    * no returns
    */
    function delegateNewAirdropForMovie(uint256 _movieID, bytes32 _merkleRoot, uint256 _startAt, uint256 _endAt) onlyOwner public {
        require(availableAirdrops[_movieID].startAt <= 0, "Airdrop for movie already exist.");
        availableAirdrops[_movieID] = Airdrop(_merkleRoot, _startAt, _endAt);

        emit AirdropMovieCreated(_movieID, _startAt, _endAt);
    }

    /*
    * Claim CinemaTicket for msg.sender
    *
    * Ticket could be claimed once per airdrop
    * Only whitelisted address could participated
    * Before minting verify merkle proof
    *
    */
    function claim(uint256 _movieID, bytes32[] calldata _merkleProof) requireValidAirdrop(_movieID) public {
        Airdrop memory airdrop = availableAirdrops[_movieID];
        bytes32 node = keccak256(abi.encodePacked(msg.sender));

        require(!addressesClaimed[_movieID][msg.sender], "Already claimed!");
        require(MerkleProof.verify(_merkleProof, airdrop.merkleRoot, node), "Invalid proof.");

        CinemaTicket(cinemaTicketAddress).mint(msg.sender, _movieID, 0);
        addressesClaimed[_movieID][msg.sender] = true;

        emit Claimed(msg.sender, _movieID);
    }

}
