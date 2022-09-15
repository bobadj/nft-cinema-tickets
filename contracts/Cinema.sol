// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Cinema is Ownable {
    using SafeMath for uint;
    using Counters for Counters.Counter;

    struct Hall {
        string name;
        uint256 totalSeats;
        uint256 availableSeats;
    }

    struct Movie {
        uint256 hallID;
        string title;
        uint256 startTime;
        uint256 ticketPrice;
    }

    Counters.Counter private movieIDCounter;
    Counters.Counter private hallIDCounter;

    address private cinemaTokenAddress;

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
    event HallCreate(uint256 hallID, uint256 totalSeats);
    event TicketBooked(address buyer, uint256 fligtID);
    event TicketCanceled(address buyer, uint256 flightID);

    /**
    * Sets CinemaToken address on deploy
    */
    constructor(address _cinemaTokenAddress) {
        cinemaTokenAddress = _cinemaTokenAddress;
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
    * @return Hall struct with the specified _hallID
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
    function addNewHall(string memory _name, uint256 _totalSeats) onlyOwner public {}

    /**
    * Creates a new movie
    *
    * @param _hallID - ID of the hall that movie will be projected
    * @param _title - title of an movie
    * @param _startTime - time on projection as timestamp
    * @param _ticketPrice - price per ticket
    *
    * no returns
    */
    function addNewMovie(uint256 _hallID, string memory _title, uint256 _startTime, uint256 _ticketPrice) requireValidHall(_hallID) onlyOwner public {}

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
    function bookTicket(uint256 _movieID, uint256 _seats) requireValidMovie(_movieID) public payable {}

    /**
    * Cancels a ticket for movie
    *
    * @param _movieID - ID of the movie
    *
    * @notice should track msg.sender tickets, refund amount and then burned a CinemaTicket token
    *
    * no returns
    */
    function cancelTicket(uint256 _movieID) requireValidMovie(_movieID) public payable {}
}
