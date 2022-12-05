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

    mapping(uint256 => Hall) private halls;
    mapping(uint256 => Movie) private movies;

    modifier requireValidHall(uint256 _hallID) {
        require(_hallID < Counters.current(hallIDCounter), "Hall does not exist.");
        _;
    }

    modifier requireValidMovie(uint256 _movieID) {
        require(_movieID < Counters.current(movieIDCounter), "Movie does not exits.");
        _;
    }

    event Received(address, uint);
    event HallCreated(uint256 hallID, string name, uint256 totalSeats);
    event MovieCreated(uint256 movieID, uint256 hallID, string title);
    event TicketBooked(address buyer, uint256 movieID);
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
    * Gets a movie
    *
    * @param _movieID - ID of movie to be retrieved
    *
    * @return Movie struct with the specified _movieID
    */
    function getMovie(uint256 _movieID) requireValidMovie(_movieID) public view returns (Movie memory) {
        return movies[_movieID];
    }

    /**
    * Gets a hall
    *
    * @param _hallID - ID of hall to be retrieved
    *
    * @return Hall struct
    */
    function getHall(uint256 _hallID) requireValidHall(_hallID) public view returns(Hall memory) {
        return halls[_hallID];
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

        uint256 currentID = Counters.current(hallIDCounter);
        halls[currentID] = Hall(_name, _totalSeats);

        Counters.increment(hallIDCounter);
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

        uint256 currentID = Counters.current(movieIDCounter);
        movies[currentID] = Movie(_hallID, _title, _startTime, _ticketPrice, hall.totalSeats);

        Counters.increment(movieIDCounter);
        emit MovieCreated(currentID, _hallID, _title);
    }

    /**
    * Books a ticket for a movie
    *
    * @param _movieID - ID of the movie
    * @param _seats - number of seats for booked ticket
    *
    * @notice should mint a CinemaTicket token
    *
    * no returns
    */
    function bookTicket(uint256 _movieID, uint256 _seats) requireValidMovie(_movieID) public payable {
        Movie memory movie = movies[_movieID];
        require(movie.startTime > block.timestamp, "Movie has already started.");
        require(movie.availableTickets > _seats, "There is no enough seats available for this movie.");
        require(msg.value >= movie.ticketPrice * _seats, "Amount applied does not match to cost.");

        address payable contractAddress = payable(address(this));
        (bool sent,) = contractAddress.call{value : movie.ticketPrice * _seats}("");
        require(sent, "Failed to send Ether.");

        CinemaTicket(tokenAddress).mint(msg.sender, _movieID, _seats, movie.ticketPrice * _seats, movie.title);

        movie.availableTickets = movie.availableTickets - _seats;
        movies[_movieID] = movie;
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
        uint256 ticketID = CinemaTicket(tokenAddress).getTokenIdFromMovieAndAddress(_movieID, msg.sender);
        CinemaTicket.TicketMetadata memory ticketMeta = CinemaTicket(tokenAddress).getTokenMetadata(ticketID);
        address buyer = ticketMeta.buyer;

        require(buyer != address(0), "You dont have tickets for this flight.");

        // 100% refund by default
        uint256 refundAmount = ticketMeta.totalCost;
        // less then 2h 50% refund
        if (movie.startTime - 7200 <= block.timestamp)
            refundAmount = movie.ticketPrice / 2;
        // less then 1h 20% refund
        if (movie.startTime - 3600 <= block.timestamp)
            refundAmount = movie.ticketPrice / 5;

        (bool sent,) = payable(buyer).call{value : refundAmount}("");
        require(sent, "Failed to send Ether.");
        CinemaTicket(tokenAddress).burn(ticketMeta, ticketID);

        movie.availableTickets = movie.availableTickets + ticketMeta.totalSeats;
        movies[_movieID] = movie;

        emit TicketCanceled(msg.sender, _movieID);
    }
}
