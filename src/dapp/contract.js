import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";
import Config from "./config.json";
import Web3 from "web3";

export default class Contract {
  constructor(network, callback) {
    let config = Config[network];
    this.web3 = new Web3(
      new Web3.providers.WebsocketProvider(config.url.replace("http", "ws"))
    );
    this.flightSuretyApp = new this.web3.eth.Contract(
      FlightSuretyApp.abi,
      config.appAddress
    );
    this.flightSuretyData = new this.web3.eth.Contract(
        FlightSuretyData.abi,
      config.dataAddress
    );
    this.initialize(callback);
    this.owner = null;
    this.airlines = [];
    this.passengers = [];
  }

  async getAccountBalance() {
      let self = this;
    // const wallet = await self.flightSuretyData.methods.passengerWallet(self.passengers[1]).call();
    // console.log('wallet')
    // console.log(wallet);
    const balance = await this.web3.eth.getBalance(self.passengers[1]);
    return this.web3.utils.fromWei(balance, "ether");
  }

  flightStatusResponse(callback) {
    let self = this;

    self.flightSuretyApp.events
      .FlightStatusInfo({
        fromBlock: 0,
      })
      .on("data", (event) => {
        console.log("event", event);
        return callback({
          airline: event?.returnValues.airline,
          requester: event?.returnValues.requester,
          flight: event?.returnValues.flight,
          timestamp: event?.returnValues.timestamp,
          status: event?.returnValues.status,
        });
      })
      .on("error", (err) => console.log(err));
  }

  requestPayout(callback) {
    let self = this;
    self.flightSuretyApp.methods
      .requestPayout()
      .send({ from: self.passengers[1], gas: 2056540 }, callback);
  }

  initialize(callback) {
    this.web3.eth.getAccounts((error, accounts) => {
      this.owner = accounts[0];

      let counter = 2;

      while (this.airlines.length < 5) {
        this.airlines.push(accounts[counter++]);
      }

      while (this.passengers.length < 5) {
        this.passengers.push(accounts[30 + counter++]);
      }

      callback();
    });
  }

  isOperational(callback) {
    let self = this;
    self.flightSuretyApp.methods
      .isOperational()
      .call({ from: self.owner }, callback);
  }

  buyInsurance(data, callback) {
    let self = this;
    let payload = {
      airline: data.airline,
      flight: data.flight,
      timestamp: data.timestamp,
    };
    self.flightSuretyApp.methods
      .buyInsurance(payload.airline, payload.flight, payload.timestamp)
      .send(
        {
          from: self.passengers[1],
          value: (data.amount * 1000000000000000000).toString(),
        },
        (error, result) => {
          callback(error, payload);
        }
      );
  }

  fetchFlightStatus(flight, callback) {
    let self = this;
    let payload = {
      airline: flight.airline,
      flight: flight.flight,
      timestamp: flight.timestamp
    };
    self.flightSuretyApp.methods
      .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
      .send({ from: self.passengers[1] }, (error, result) => {
        callback(error, payload);
      });
  }
}
