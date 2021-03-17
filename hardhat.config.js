const fs = require('fs');
let secrets;
if (fs.existsSync('secrets.json')) {
   secrets = JSON.parse(fs.readFileSync('secrets.json', 'utf8'));
}

require('hardhat/types');
require('hardhat-deploy');
//require('hardhat-deploy-ethers');

let mnemonic = process.env.MNEMONIC;
if (!mnemonic) {
  // FOR DEV ONLY, SET IT IN .env files if you want to keep it private
  // (IT IS IMPORTANT TO HAVE A NON RANDOM MNEMONIC SO THAT SCRIPTS CAN ACT ON THE SAME ACCOUNTS)
  mnemonic = 'test test test test test test test test test test test vault';
}
const accounts = {
  mnemonic,
  count: 10
};

require("@nomiclabs/hardhat-truffle5");

//usePlugin('buidler-gas-reporter');
 
module.exports = {
    defaultNetwork: "hardhat",
    namedAccounts: {
       deployer: 0,
    },
    networks: {
        localhost : {
          url: 'http://127.0.0.1:7545/'
        },
        hardhat: {
           chainId: 31337
        },
        mainnet: {
          chainId: 1,
          accounts,
          url: "https://mainnet.infura.io/v3/" + secrets.infuraApiKey
        },
        rinkeby: {
          chainId: 4,
          accounts,
          url: "https://rinkeby.infura.io/v3/" + secrets.infuraApiKey
        },
        bsc: {
          chainId: 56,
          accounts,
          url: "https://bsc-dataseed.binance.org/"
        },
        opera: {
          chainId: 250,
          accounts,
          url: "https://rpc.fantom.network/"
        }
  },
  solidity: {
     version: "0.7.3",
     settings: {
        optimizer: {
           enabled: true,
           runs: 200
        }
     }
   },
   paths: {
      sources: "./contracts",
      tests: "./test",
      cache: "./cache",
      artifacts: "./artifacts"
   }
     
};

require("@nomiclabs/hardhat-waffle");

