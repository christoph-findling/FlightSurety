# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

# Intro
- Run ganache with 30 accounts, copy & paste seed phrase (truffle.js) and set the first airline's address in  (accounts[1])
- Run `truffle compile` then `truffle migrate`
- Run `npm run server`, this will register airlines, fund them, register flights (from flights.js) and register oracles, then enable all API endpoints
- Run `npm run dapp`, open up the browser and go through the steps
- To get a specific statusCode from the oracles, set it as a return value for the "getRandomStatusCode()" function in the server.js file.

# Notes
- Flights get a timestamp which is set to 120sec in the future at the time the server is started and flights, airlines, oracles are registered. If the oracle request ist fired before a flight has departed, the oracle responses are not accepted by the contract. Also, insurances can only by bought for flights that have not yet departed. To verify, check the server logs 

# Improvements
- Many possible improvements, like adding better checks and storing additional data, making the frontend more UX friendly, etc.
----

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)
