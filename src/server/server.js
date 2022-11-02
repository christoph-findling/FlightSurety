import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";
import Config from "./config.json";
import Web3 from "web3";
import express from "express";
import flights from "../../flights";

const statusCodes = [0, 10, 20, 30, 40, 50];

const airlines = [];
const oracles = [];
const registeredOracles = [];

const options = {
  // Enable auto reconnection
  reconnect: {
    auto: true,
    delay: 5000, // ms
    maxAttempts: 5,
    onTimeout: false,
  },
};

let config = Config["localhost"];
let web3 = new Web3(
  new Web3.providers.WebsocketProvider(config.url.replace("http", "ws")),
  options
);
let accounts = [];

web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(
  FlightSuretyApp.abi,
  config.appAddress
);
let flightSuretyData = new web3.eth.Contract(
  FlightSuretyData.abi,
  config.dataAddress
);

web3.eth.getAccounts(async (err, acc) => {
  console.log(flightSuretyApp._address);
  await flightSuretyData.methods
    .addAuthorizedContract(flightSuretyApp._address)
    .send({ from: acc[0], gas: 2506540 });

  web3.eth.defaultAccount = acc[0];
  accounts = acc;
  // account[0] = owner, account[1] = airline registered at init
  for (let i = 2; i < 12; i++) {
    airlines.push(accounts[i]);
  }
  for (let i = 0; i < flights.length; i++) {
    flights[i].airline = airlines[flights[i].airline];
    let now = new Date();
    now.setSeconds(now.getSeconds() + 120); // departs in 120sec.
    const inMs = Date.parse(now);
    const inSec = Math.floor(inMs / 1000);
    flights[i].timestamp = inSec;
  }
  for (let i = 12; i < 31; i++) {
    oracles.push(accounts[i]);
  }
  await registerAirlines();
  await fundAirlines();
  await registerFlights();
  await registerOracles();
  console.log("endpoints ready");
  enableEndpoints();

  flightSuretyApp.events.OracleRequest(
    {
      fromBlock: 0,
    },
    async (error, event) => {
      if (error) console.log(error);
      handleOracleRequest(event.returnValues);
    }
  );

  flightSuretyApp.events.FlightStatusInfo(
    {
      fromBlock: 416,
    },
    async (error, event) => {
      if (error) console.log(error);
      console.log("FLIGHT STATUS INFO");
      console.log(event);
    }
  );
  return;
});

async function handleOracleRequest(data) {
  console.log("GOT ORACLE REQ");
  console.log(data);
  for (const oracle of registeredOracles) {
    if (!!oracle.indices.find((index) => index == data.index)) {
      console.log("oracle match");
      const res = {
        index: data.index,
        airline: data.airline,
        flight: data.flight,
        timestamp: data.timestamp,
        statusCode: getRandomStatusCode(),
      };
      try {
        console.log("send oracle response");
        console.log(res);
        // Might return a "already received enough oracle responses" error
        let res1 = await flightSuretyApp.methods
          .submitOracleResponse(
            res.index,
            res.airline,
            res.flight,
            res.timestamp,
            res.statusCode
          )
          .send({ from: oracle.address, gas: 2506540 });
        console.log("sent oracle response");
        console.log(res1);
      } catch (e) {
        console.log(e);
      }
    }
  }
}

function getRandomStatusCode() {
  return statusCodes[Math.floor(Math.random() * 5.5)];
}

const app = express();
function enableEndpoints() {
  app.get("/api", (req, res) => {
    res.header("Access-Control-Allow-Origin", "*");

    res.header(
      "Access-Control-Allow-Headers",
      "Origin, X-Requested-With, Content-Type, Accept"
    );

    res.send({
      message: "An API for use with your Dapp!",
    });
  });

  app.get("/api/flights", (req, res) => {
    res.header("Access-Control-Allow-Origin", "*");

    res.header(
      "Access-Control-Allow-Headers",
      "Origin, X-Requested-With, Content-Type, Accept"
    );

    res.send({
      data: flights,
    });
  });
}

async function registerAirlines() {
  for (const airline of airlines) {
    try {
      await flightSuretyApp.methods
        .registerAirline(airline)
        .send({ from: accounts[1], gas: 2506540 });
    } catch (e) {}
  }

  console.log("registered airlines");
}

async function fundAirlines() {
  for (const airline of airlines) {
    try {
      await flightSuretyApp.methods.fundAirline().send({
        from: airline,
        value: web3.utils.toWei("10", "ether"),
      });
    } catch (e) {}
  }
  console.log("funded airlines");
}

async function registerFlights() {
  for (var flight of flights) {
    try {
      await flightSuretyApp.methods
        .registerFlight(flight.flight, flight.timestamp)
        .send({ from: flight.airline, gas: 2506540 });
    } catch (e) {}
  }
  console.log("registered flights");
}

async function registerOracles() {
  const regFee = await flightSuretyApp.methods.REGISTRATION_FEE().call();

  for (const oracle of oracles) {
    await flightSuretyApp.methods.registerOracle().send({
      from: oracle,
      value: regFee.toString(),
      gas: 2506540,
    });
    const indices = await flightSuretyApp.methods
      .getMyIndices()
      .call({ from: oracle });
    registeredOracles.push({ address: oracle, indices });
  }
  console.log("registered oracles");
}

export default app;
