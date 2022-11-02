var Test = require("../config/testConfig.js");
var BigNumber = require("bignumber.js");

function toWei(ether) {
  return (ether * 1000000000000000000).toString();
}

const tenEth = toWei(10);

contract("Flight Surety Tests", async (accounts) => {
  var config;
  const deploy = async function () {
    config = await Test.Config(accounts);
    await config.flightSuretyData.addAuthorizedContract(
      config.flightSuretyApp.address
    );
  };

  describe("Operations and settings", () => {
    before(deploy);

    //     /****************************************************************************************/
    //     /* Operations and settings                                                              */
    //     /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {
      // Get operating status
      let status = await config.flightSuretyData.isOperational.call();
      assert.equal(status, true, "Incorrect initial operating status value");
    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try {
        await config.flightSuretyData.setOperatingStatus(false, {
          from: config.testAddresses[2],
        });
      } catch (e) {
        accessDenied = true;
      }
      assert.equal(
        accessDenied,
        true,
        "Access not restricted to Contract Owner"
      );
    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try {
        await config.flightSuretyData.setOperatingStatus(false);
      } catch (e) {
        accessDenied = true;
      }
      assert.equal(
        accessDenied,
        false,
        "Access not restricted to Contract Owner"
      );

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);
    });
  });

  /****************************************************************************************/
  /* Airline registration, funding, voting                                                */
  /****************************************************************************************/
  describe("Airline registration", async () => {
    before(deploy);

    it("(airline) cannot register an Airline using registerAirline() if it is not funded itself yet", async () => {
      // ARRANGE
      let newAirline = accounts[4];
      let newAirline2 = accounts[5];

      // ACT
      try {
        await config.flightSuretyApp.registerAirline(newAirline, {
          from: newAirline2,
        });
      } catch (e) {}

      let result = null;
      try {
        result = await config.flightSuretyData.isAirline.call(newAirline);
      } catch (e) {}

      // ASSERT
      assert.equal(
        result,
        false,
        "Airline should not be able to register another airline if it hasn't provided funding"
      );
    });
  });

  describe("Airline funding", async () => {
    before(deploy);
    it("(airline) cannot fund airline due to insufficient ethers sent", async () => {
      // ARRANGE
      const newAirline = accounts[6];

      // ACT
      try {
        await config.flightSuretyApp.registerAirline(newAirline, {
          from: config.firstAirline,
        });
      } catch (e) {}

      let result = false;

      try {
        await config.flightSuretyApp.fundAirline({
          from: newAirline,
        });
        result = true;
      } catch (e) {}

      // ASSERT
      assert.equal(
        result,
        false,
        "Airline should not be able to fund other airline (bc min. funding amount is 10 ether)"
      );
    });
  });
});
