require('dotenv').config();
require("@nomiclabs/hardhat-waffle");

const alchemyApiKey = process.env.ALCHEMY_API_KEY;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.0",
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-kovan.alchemyapi.io/v2/${alchemyApiKey}"
      }
    }
  }  
};
