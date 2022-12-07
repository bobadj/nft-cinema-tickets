import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { utils } from "ethers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";

describe("Cinema Ticket Airdrop", function () {
    let cinemaTicketAirdrop, cinemaTicket, owner, otherAccount, availableSigners, root, merkleTree, nodes;
    const movieID = 1,
          dayInASeconds = 86400,
          airdropStartAt = Number((new Date().getTime() / 1000)).toFixed(0),
          airdropEndAt = Number((new Date().getTime() / 1000) + (dayInASeconds * 2)).toFixed(0);

    before("Deploy the contracts first", async function() {
        availableSigners = await ethers.getSigners();
        [owner, otherAccount] = availableSigners;
        // merkle tree with first 5 addresses
        const whitelistedAddress = availableSigners
            .map(function( signer: SignerWithAddress, ) {
                return signer.address
            })
            .splice(0, 5);

        nodes = whitelistedAddress.map((x) =>
            utils.solidityKeccak256(["address"], [x])
        );
        merkleTree = new MerkleTree(nodes, keccak256, { sort: true });
        // merkle root
        root = merkleTree.getHexRoot();

        // deploy CinemaTicket contract
        const CinemaTicket = await ethers.getContractFactory("CinemaTicket");
        cinemaTicket = await CinemaTicket.deploy();
        await cinemaTicket.deployed();

        // deploy CinemaTicketAirdrop contract with CinemaTicket address in constructor
        const CinemaTicketAirdrop = await ethers.getContractFactory("CinemaTicketAirdrop");
        cinemaTicketAirdrop = await CinemaTicketAirdrop.deploy(cinemaTicket.address);
        await cinemaTicketAirdrop.deployed();

        // grants minter role for CinemaTicketAirdrop contract
        const minterRole = utils.solidityKeccak256(['string'], ['MINTER_ROLE']);
        const tsx = await cinemaTicket.grantRole(minterRole.toString(), cinemaTicketAirdrop.address);
        await tsx.wait(1);
    });

    it("Should create new airdrop", async () => {
        await expect(cinemaTicketAirdrop.delegateNewAirdropForMovie(movieID, root, airdropStartAt, airdropEndAt))
            .to.emit(cinemaTicketAirdrop, "AirdropMovieCreated")
            .withArgs(movieID, airdropStartAt, airdropEndAt);

        await expect(cinemaTicketAirdrop.delegateNewAirdropForMovie(2, root, airdropStartAt+dayInASeconds, airdropEndAt))
            .to.emit(cinemaTicketAirdrop, "AirdropMovieCreated")
            .withArgs(2, airdropStartAt+dayInASeconds, airdropEndAt);
    });

    it("Should claim it successfully", async () => {
        const proof = merkleTree.getHexProof(nodes[3]);

        // Attempt to claim and verify success
        await expect(cinemaTicketAirdrop.connect(availableSigners[3]).claim(movieID, proof))
            .to.emit(cinemaTicketAirdrop, "Claimed")
            .withArgs(availableSigners[3].address, movieID);
    });

    it("Should throw for airdrop already exist", async () => {
        await expect(cinemaTicketAirdrop.delegateNewAirdropForMovie(movieID, root, airdropStartAt, airdropEndAt))
            .to.be.revertedWith("Airdrop for movie already exist.");
    });

    it("Should throw for airdrop has not yet started", async () => {
        const proof = merkleTree.getHexProof(nodes[3]);

        // Attempt to claim and verify error
        await expect(cinemaTicketAirdrop.connect(availableSigners[3]).claim(2, proof))
            .to.be.revertedWith("Airdrop has not started yet.");
    });

    it("Should throw for already claimed", async () => {
        const proof = merkleTree.getHexProof(nodes[3]);

        // Attempt to claim and verify error
        await expect(cinemaTicketAirdrop.connect(availableSigners[3]).claim(movieID, proof))
            .to.be.revertedWith("Already claimed!");
    });

    it("Should throw for invalid proof", async () => {
        // call with invalid proof
        await expect(cinemaTicketAirdrop.connect(availableSigners[2]).claim(movieID, []))
            .to.be.revertedWith("Invalid proof.");

        const proof = merkleTree.getHexProof(availableSigners[10].address);
        // call with non-legit address
        await expect(cinemaTicketAirdrop.connect(availableSigners[10]).claim(movieID, proof))
            .to.be.revertedWith("Invalid proof.");
    });

    it("Should throw for invalid airdrop", async () => {
        const proof = merkleTree.getHexProof(nodes[3]);

        // Attempt to claim and verify error
        await expect(cinemaTicketAirdrop.connect(availableSigners[3]).claim(5, proof))
            .to.be.revertedWith("Airdrop for desired movie do not exist!");
    });
});
