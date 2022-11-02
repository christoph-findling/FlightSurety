var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "omit mansion urban chair gather limb delay paper teach item muscle outer";

module.exports = {
  networks: {
    // development: {

    //   provider: function() {
    //     return new HDWalletProvider(mnemonic, "http://127.0.0.1:9545/", 0, 50);
    //   },
    //   network_id: '*',
    //   //gas: 999999
    // }
    
  // Had to remove the HDWalletProvider to resolve a tx error
    development: {
      host: "127.0.0.1",     // Localhost
      port: 9545,            // Standard Ganache UI port
      network_id: "*", 
      //gas: 4600000
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};