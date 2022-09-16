import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

describe("Cinema", function () {
    async function deployContract() {
        const [owner, otherAccount] = await ethers.getSigners();
        // first deploy CinemaTicket contract
        const CinemaTicket = await ethers.getContractFactory("CinemaTicket");
        const cinemaTicket = await CinemaTicket.deploy();
        // deploy Cinema contract with CinemaTicket address applied
        const Cinema = await ethers.getContractFactory("Cinema");
        const cinema = await Cinema.deploy(cinemaTicket.address);

        // Contracts are deployed using the first signer/account by default
        return { cinemaTicket, cinema, owner, otherAccount };
    }

    describe("Testing contract", function () {
        it("Should create a new hall", async function() {
            const { cinema } = await loadFixture(deployContract);

            const hallName = "Cineplexx Beograd";
            const hallSeats = 20;

            await cinema.addNewHall(hallName, BigNumber.from(hallSeats));
            const hall = await cinema.getHall(0);

            describe("Test hall details", function () {
                it("Name should be correct", async function() {
                    expect(hall.name).to.be.eq(hallName);
                });
                it("Check seats", async function() {
                    expect(+hall.totalSeats.toNumber()).to.be.eq(hallSeats);
                    expect(+hall.availableSeats.toNumber()).to.be.eq(hallSeats);
                });
                it("Should create new movie", async function() {
                    const movieTitle = "Awesome movie.";
                    const movieStartTime = Number((new Date().getTime() / 1000) + 86400).toFixed(0);
                    const movieTicketPrice = (0.002 * 1e18).toFixed(0);
                    await cinema.addNewMovie(BigNumber.from(0), movieTitle, BigNumber.from(movieStartTime), BigNumber.from(movieTicketPrice));

                    describe("Book/cancel tickets for a movie", function () {
                        it("Should book tickets for a movie", async function() {
                            await cinema.bookTicket(
                                BigNumber.from(0),
                                BigNumber.from(2),
                                {
                                    value: movieTicketPrice * 2
                                }
                            )
                        })
                        it("Cinema contract should have funds", async function() {
                            const cinemaFunds = await cinema.provider.getBalance(cinema.address);
                            expect(cinemaFunds.toNumber()).to.be.eq(movieTicketPrice*2);
                        })
                        it("Should cancel tickets", async function() {
                            await cinema.cancelTicket(0);
                        })
                        it("Cinema contract should have less funds", async function() {
                            const cinemaFunds = await cinema.provider.getBalance(cinema.address);
                            expect(cinemaFunds.toNumber()).to.be.eq(+movieTicketPrice);
                        })
                    });
                });
            });
        });
    });

});