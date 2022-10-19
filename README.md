# NFT Cinema Tickets - in progress

#### Development setup
* Clone repo
```
git clone git@github.com:bobadj/nft-cinema-tickets.git
```
* Install dependencies via ``yarn``
```
cd nft-cinema-tickets/
yarn install
```
* Test with gas reporter:
```
cross-env-shell GAS_REPORTER=true yarn hardhat test
```
_Note: to see gas prices `COINMARKETCAP_KEY` is required, could use the `.env` file or `cross-end-shell` to set it_
