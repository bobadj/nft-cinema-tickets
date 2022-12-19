// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./CinemaTicket.sol";

contract Cinema is Ownable {
    using SafeMath for uint;
    using Counters for Counters.Counter;

    uint256 private availableForWithdraw;
    address public immutable tokenAddress;

    Counters.Counter private movieIDCounter;
    Counters.Counter private hallIDCounter;

    mapping(uint256 => Hall) public halls;
    mapping(uint256 => Movie) public movies;

    struct Hall {
        string name;
        uint256 totalSeats;
    }

    struct Movie {
        string title;
        uint256 hallID;
        uint256 startTime;
        uint256 ticketPrice;
        uint256 availableTickets;
    }

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
    event TicketCanceled(address indexed buyer, uint256 movieID);
    event Withdrawal();

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

    /*
    * Withdraw funds to owner
    *
    * @notice be careful! contract should have enough funds to refund tickets
    * @notice available for contract owner only
    *
    * no returns
    */
    function withdraw(uint256 _amount) onlyOwner public payable {
        require(address(this).balance >= _amount, "No enough balance.");
        // override _amount in case bellow?
        require(availableForWithdraw >= _amount, "Not allowed to withdraw that much.");

        availableForWithdraw = availableForWithdraw.sub(_amount);

        address payable ownerAddress = payable(address(owner()));
        (bool sent,) = ownerAddress.call{value : _amount}("");
        require(sent, "Failed to send Ether.");

        emit Withdrawal();
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
        movies[currentID] = Movie(_title, _hallID, _startTime, _ticketPrice, hall.totalSeats);

        movieIDCounter.increment();
        emit MovieCreated(currentID, _hallID, _title);
    }

    /**
    * Books a ticket for a movie
    *
    * @param _movieID - ID of the movie
    * @param _tokenURI - token uri ( ipfs cid )
    *
    * @notice should mint a CinemaTicket token
    *
    * no returns
    */
    function bookTicket(uint256 _movieID, string memory _tokenURI) requireValidMovie(_movieID) public payable {
        Movie memory movie = movies[_movieID];
        require(movie.startTime > block.timestamp, "Movie has already started.");
        require(movie.availableTickets > 0, "There is no enough seats available for this movie.");
        require(msg.value >= movie.ticketPrice, "Amount applied does not match to cost.");

        movie.availableTickets = movie.availableTickets - 1;
        movies[_movieID] = movie;

        address payable contractAddress = payable(address(this));
        (bool sent,) = contractAddress.call{value : movie.ticketPrice}("");
        require(sent, "Failed to send Ether.");

        CinemaTicket(tokenAddress).mint(msg.sender, _movieID, movie.ticketPrice, _tokenURI);

        emit TicketBooked(msg.sender, _movieID);
    }

    /**
    * Cancels a ticket for movie
    *
    * @param _ticketID - ticket ID
    *
    * @notice refund amount and burn CinemaTicket token
    * @notice update availableForWithdraw
    *
    * no returns
    */
    function cancelTicket(uint256 _ticketID) public payable {
        CinemaTicket cinemaTicket = CinemaTicket(tokenAddress);
        CinemaTicket.TicketMetadata memory ticketMeta = cinemaTicket.getTokenMetadata(_ticketID);
        Movie memory movie = movies[ticketMeta.movieID];
        require(!ticketMeta.checkedIn, "Ticket is already used.");
        require(movie.startTime > block.timestamp, "Movie has already started.");

        address buyer = cinemaTicket.ownerOf(_ticketID);
        require(buyer == msg.sender, "You are not the owner of the ticket.");
        require(buyer != address(0), "You dont have tickets for this movie.");

        // 100% refund by default
        uint256 refundPercentage = 100;
        // less then 2h 50% refund
        if (movie.startTime - 7200 <= block.timestamp)
            refundPercentage = 50;
        // less then 1h 25% refund
        if (movie.startTime - 3600 <= block.timestamp)
            refundPercentage = 25;
        uint256 refundAmount = ticketMeta.totalCost.mul(refundPercentage.mul(100)).div(10000);
        availableForWithdraw = availableForWithdraw.add(ticketMeta.totalCost.sub(refundAmount));

        CinemaTicket(tokenAddress).burn(_ticketID);

        movie.availableTickets = movie.availableTickets + 1;
        movies[ticketMeta.movieID] = movie;

        (bool sent,) = payable(buyer).call{value : refundAmount}("");
        require(sent, "Failed to send Ether.");

        emit TicketCanceled(msg.sender, ticketMeta.movieID);
    }

    /*
    * Check-in Ticket/mark as used
    *
    * @param _ticketID - ID of ticket
    *
    * @notice check-in is available 30min before projection
    *
    * no returns
    */
    function checkInTicket(uint256 _ticketID) public {
        CinemaTicket cinemaTicket = CinemaTicket(tokenAddress);
        CinemaTicket.TicketMetadata memory ticketMeta = cinemaTicket.getTokenMetadata(_ticketID);
        Movie memory movie = movies[ticketMeta.movieID];
        require(movie.startTime - 1800 < block.timestamp, "Not available for check-in yet.");

        availableForWithdraw = availableForWithdraw.add(ticketMeta.totalCost);
        // burn token instead of check-in?
        cinemaTicket.markAsCheckedIn(_ticketID);
    }
}
