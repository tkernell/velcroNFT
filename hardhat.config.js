require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");

const alchemyApiKey = process.env.ALCHEMY_API_KEY;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.2",
    settings: {
      optimizer: {
        enabled: true,
        runs: 50
      }
    }
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-kovan.alchemyapi.io/v2/TWw8NsAB8EazJ4xns6G9YAdcVkLYe2Hn",
	blockNumber: 24549213
      }
    }
  }
};
