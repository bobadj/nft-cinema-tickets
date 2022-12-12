// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./CinemaTicket.sol";

contract Cinema is Ownable {
    using SafeMath for uint;
    using Counters for Counters.Counter;

    address public immutable tokenAddress;

    struct Hall {
        string name;
        uint256 totalSeats;
    }

    struct Movie {
        uint256 hallID;
        string title;
        uint256 startTime;
        uint256 ticketPrice;
        uint256 availableTickets;
    }

    Counters.Counter private movieIDCounter;
    Counters.Counter private hallIDCounter;

    mapping(uint256 => Hall) public halls;
    mapping(uint256 => Movie) public movies;

    modifier requireValidHall(uint256 _hallID) {
        require(_hallID < hallIDCounter.current(), "Hall does not exist.");
        require(bytes(halls[_hallID].name).length > 0, "Hall does not exist.");
        _;
    }

    modifier requireValidMovie(uint256 _movieID) {
        require(_movieID < movieIDCounter.current(), "Movie does not exits.");
        require(bytes(movies[_movieID].title).length > 0, "Movie does not exist.");
        _;
    }

    event Received(address, uint);
    event HallCreated(uint256 hallID, string name, uint256 totalSeats);
    event MovieCreated(uint256 movieID, uint256 hallID, string title);
    event TicketBooked(address indexed buyer, uint256 movieID);
    event TicketCanceled(address buyer, uint256 movieID);

    /*
    * Save ERC721 token address
    *
    * @param _tokenAddress - ERC721 token address
    *
    */
    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
    * Creates a new hall
    *
    * @param _name - name of hall
    * @param _totalSeats - number of seats available in hall
    *
    * @notice available for contract owner only
    * no returns
    */
    function addNewHall(string memory _name, uint256 _totalSeats) onlyOwner public {
        require(bytes(_name).length > 0, "Hall name is required.");
        require(_totalSeats > 0, "New hall must have at least one seats available.");

        uint256 currentID = hallIDCounter.current();
        halls[currentID] = Hall(_name, _totalSeats);

        hallIDCounter.increment();
        emit HallCreated(currentID, _name, _totalSeats);
    }

    /**
    * Creates a new movie
    *
    * @param _hallID - ID of the hall that movie will be projected
    * @param _title - title of an movie
    * @param _startTime - time on projection as timestamp
    * @param _ticketPrice - price per ticket
    *
    * toDo - determinate if hall is busy at the moment of projection
    *
    * @notice available for contract owner only
    * no returns
    */
    function addNewMovie(uint256 _hallID, string memory _title, uint256 _startTime, uint256 _ticketPrice) onlyOwner requireValidHall(_hallID) onlyOwner public {
        require(bytes(_title).length > 0, "Movie must have a title.");
        require(_startTime > block.timestamp, "Movie projection must be in a future.");

        Hall memory hall = halls[_hallID];

        uint256 currentID = movieIDCounter.current();
        movies[currentID] = Movie(_hallID, _title, _startTime, _ticketPrice, hall.totalSeats);

        movieIDCounter.increment();
        emit MovieCreated(currentID, _hallID, _title);
    }

    /**
    * Books a ticket for a movie
    *
    * @param _movieID - ID of the movie
    *
    * @notice should mint a CinemaTicket token
    *
    * no returns
    */
    function bookTicket(uint256 _movieID) requireValidMovie(_movieID) public payable {
        Movie memory movie = movies[_movieID];
        require(movie.startTime > block.timestamp, "Movie has already started.");
        require(movie.availableTickets > 0, "There is no enough seats available for this movie.");
        require(msg.value >= movie.ticketPrice, "Amount applied does not match to cost.");

        movie.availableTickets = movie.availableTickets - 1;
        movies[_movieID] = movie;

        address payable contractAddress = payable(address(this));
        (bool sent,) = contractAddress.call{value : movie.ticketPrice}("");
        require(sent, "Failed to send Ether.");

        CinemaTicket(tokenAddress).mint(msg.sender, _movieID, movie.ticketPrice);

        emit TicketBooked(msg.sender, _movieID);
    }

    /**
    * Cancels a ticket for movie
    *
    * @param _movieID - ID of the movie
    *
    * @notice should track msg.sender tickets, refund amount and then burned a CinemaTicket token
    *
    * no returns
    */
    function cancelTicket(uint256 _movieID) requireValidMovie(_movieID) public payable {
        Movie memory movie = movies[_movieID];
        require(movie.startTime > block.timestamp, "Movie has already started.");
        CinemaTicket cinemaTicket = CinemaTicket(tokenAddress);
        uint256 ticketID = cinemaTicket.movieTokenMap(_movieID);
        require(ticketID > 0, "There is not ticket associated with movie.");
        address buyer = cinemaTicket.ownerOf(ticketID);

        require(buyer == msg.sender, "You are not the owner of the ticket.");
        require(buyer != address(0), "You dont have tickets for this movie.");

        CinemaTicket.TicketMetadata memory ticketMeta = cinemaTicket.getTokenMetadata(ticketID);
        // 100% refund by default
        uint256 refundPercentage = 100;
        // less then 2h 50% refund
        if (movie.startTime - 7200 <= block.timestamp)
            refundPercentage = 50;
        // less then 1h 25% refund
        if (movie.startTime - 3600 <= block.timestamp)
            refundPercentage = 25;
        uint256 refundAmount = (ticketMeta.totalCost * (refundPercentage*100)) / 10000;

        CinemaTicket(tokenAddress).burn(ticketID);

        movie.availableTickets = movie.availableTickets + 1;
        movies[_movieID] = movie;

        (bool sent,) = payable(buyer).call{value : refundAmount}("");
        require(sent, "Failed to send Ether.");

        emit TicketCanceled(msg.sender, _movieID);
    }
}
