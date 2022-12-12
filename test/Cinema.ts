import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber, utils } from "ethers";

describe("Cinema", function () {
    let cinemaTicket, cinema, owner, otherAccount;
    const movieTitle = "Awesome movie.",
          hallID = 0,
          movieStartTime = Number((new Date().getTime() / 1000) + 3600).toFixed(0),
          movieTicketPrice = (0.002 * 1e18).toFixed(0);

    before("Deploy the contracts first", async function() {
        [owner, otherAccount] = await ethers.getSigners();
        // deploy CinemaTicket contract
        const CinemaTicket = await ethers.getContractFactory("CinemaTicket");
        cinemaTicket = await CinemaTicket.deploy();
        await cinemaTicket.deployed();
        // deploy Cinema contract with CinemaTicket address in constructor
        const Cinema = await ethers.getContractFactory("Cinema");
        cinema = await Cinema.deploy(cinemaTicket.address);
        await cinema.deployed();

        // grants minter role for Cinema contract
        const minterRole = utils.solidityKeccak256(['string'], ['MINTER_ROLE']);
        const tsx = await cinemaTicket.grantRole(minterRole.toString(), cinema.address);
        await tsx.wait(1);
    });

    it("Should create a new hall", async function() {
        const hallName = "Cineplexx Beograd";
        const hallSeats = 20;

        await expect(cinema.addNewHall(hallName, BigNumber.from(hallSeats)))
            .to.emit(cinema, "HallCreated")
            .withArgs(0, hallName, BigNumber.from(hallSeats));

        const createdHall = await cinema.halls(0);
        expect(createdHall.name).to.be.eq(hallName);
        expect(createdHall.totalSeats).to.be.eq(BigNumber.from(hallSeats));
    });

    it("Should create a new movie", async function() {
        await expect(cinema.addNewMovie(hallID, movieTitle, BigNumber.from(movieStartTime), BigNumber.from(movieTicketPrice)))
            .to.emit(cinema, "MovieCreated")
            .withArgs(0, hallID, movieTitle);

        const createdMovie = await cinema.movies(0);

        expect(createdMovie.hallID).to.be.eq(BigNumber.from(hallID));
        expect(createdMovie.title).to.be.eq(movieTitle);
        expect(createdMovie.startTime).to.be.eq(BigNumber.from(movieStartTime));
        expect(createdMovie.ticketPrice).to.be.eq(BigNumber.from(movieTicketPrice));
    });

    it("Should book tickets for a movie", async function() {
        await expect(cinema.bookTicket(BigNumber.from(0), { value: movieTicketPrice }))
            .to.emit(cinema, "TicketBooked")
            .withArgs(owner.address, BigNumber.from(0));
    });

    it("Cinema contract should have funds", async function() {
        const cinemaFunds = await cinema.provider.getBalance(cinema.address);
        expect(cinemaFunds.toNumber()).to.be.eq(+movieTicketPrice);
    });

    it("Should cancel tickets", async function() {
        await expect(cinema.cancelTicket(0))
            .to.emit(cinema, "TicketCanceled")
            .withArgs(owner.address, 0);
    });

    it("Cinema contract refund 25%", async function() {
        const cinemaFunds = await cinema.provider.getBalance(cinema.address);
        expect(cinemaFunds.toNumber()).to.be.eq(movieTicketPrice - (25/100) * movieTicketPrice);
    });
});
