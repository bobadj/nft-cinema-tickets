import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
import "hardhat-gas-reporter"
dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  gasReporter: {
    enabled: process.env.GAS_REPORTER === 'true',
    coinmarketcap: process.env.COINMARKETKAY_KEY ?? null
  },
  etherscan: {
    apiKey: process.env.ETHERSCHAN_API_KEY
  }
};

export default config;
