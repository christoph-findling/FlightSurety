import DOM from "./dom";
import Contract from "./contract";
import "./flightsurety.css";

let currentSelection = null;
let currentSelection2 = null;
let flights = null;

(async () => {
  //let result = null;

  let contract = new Contract("localhost", () => {
    // Read transaction
    contract.isOperational((error, result) => {
      console.log(error, result);
      display("Operational Status", "Check if contract is operational", [
        { label: "Operational Status", error: error, value: result },
      ]);
    });

    contract.flightStatusResponse((data, error) => {
      console.log("flightstatusresponse");
      console.log(data);
      display("Flight Status Response", "", [
        {
          label: "Flight " + data.flight,
          error: error,
          value: "Status code (if 20 can request payout): " + data.status,
        },
      ]);
    });

    fetch("http://localhost:3000/api/flights") //api for the get request
      .then((response) => {
        response.json().then((res) => {
          console.log(res);
          flights = res.data;
          populateDropdowns(flights);
        });
      })
      .then((data) => console.log(data));

    DOM.elid("flights").addEventListener("click", (e) => {
      console.log(e.target.value);
      currentSelection = e.target.value;
    });

    DOM.elid("flights2").addEventListener("click", (e) => {
      console.log(e.target.value);
      currentSelection2 = e.target.value;
    });

    // User-submitted transaction
    DOM.elid("submit-oracle").addEventListener("click", () => {
      // let flight = DOM.elid("flight-number").value;
      // Write transaction. Expects (address airline, string flight)
      console.log("req for flight: ");
      console.log(flights[currentSelection]);
      contract.fetchFlightStatus(
        {
          airline: contract.airlines[currentSelection],
          flight: flights[currentSelection].flight,
          timestamp: flights[currentSelection].timestamp,
        },
        (error, result) => {
          console.log(result);
          display("Oracles", "Trigger oracles", [
            {
              label: "Fetch Flight Status",
              error: error,
              value:
                "Airline: " + result.airline + " Flight: " + result.flight + " Timestamp: " + result.timestamp,
            },
          ]);
        }
      );
    });

    // User-submitted transaction
    DOM.elid("request-payout").addEventListener("click", async () => {
      //   let flight = DOM.elid("flight-number").value;
      // Write transaction. Expects (address airline, string flight)
      const prevBalance = await contract.getAccountBalance();
      console.log(prevBalance);
      contract.requestPayout(async (error, result) => {
        console.log(result);
        console.log(error);
        display("Payout", "Result:", [
          {
            label: "New account balance",
            error: error,
            value:
              "prev balance: " +
              prevBalance +
              "ether | new balance: " +
              await contract.getAccountBalance() +
              "ether",
          },
        ]);
      });
    });

    DOM.elid("buy-insurance").addEventListener("click", () => {
      //   let flight = DOM.elid("flight-number").value;
      // Write transaction. Expects (address airline, string flight)
      let amount = DOM.elid("amount").value;
      if (amount > 1) amount = 1;
      if (amount < 0.1) amount = 0.1;
      console.log("buy insurance for flight: ");
      console.log(flights[currentSelection2]);
      console.log(amount);
      console.log(contract.airlines[currentSelection2]);
      console.log(flights[currentSelection2].flight);
console.log(flights[currentSelection2].timestamp)
      contract.buyInsurance(
        {
          airline: contract.airlines[currentSelection2],
          flight: flights[currentSelection2].flight,
          timestamp: flights[currentSelection2].timestamp,
          amount: amount.toString(),
        },
        (error, result) => {
          display("Bought insurance", "for the following flight", [
            {
              label: "Flight number & amount ",
              error: error,
              value: result.flight + " | " + amount + " ether",
            },
          ]);
        }
      );
    });
  });
})();

function populateDropdowns(flights) {
  var index = 0;
  for (var flight of flights) {
    var opt = document.createElement("option");
    var opt2 = document.createElement("option");
    opt.value = index;
    opt2.value = index;
    opt.innerHTML = flight.flight; // whatever property it has
    opt2.innerHTML = flight.flight; // whatever property it has

    // then append it to the select element
    DOM.elid("flights").appendChild(opt);
    DOM.elid("flights2").appendChild(opt2);
    if (index == 0) {
      currentSelection = 0;
      currentSelection2 = 0;
    }
    index++;
  }
}

function display(title, description, results) {
  let displayDiv = DOM.elid("display-wrapper");
  let section = DOM.section();
  section.appendChild(DOM.h2(title));
  section.appendChild(DOM.h5(description));
  results.map((result) => {
    let row = section.appendChild(DOM.div({ className: "row" }));
    row.appendChild(DOM.div({ className: "col-sm-4 field" }, result.label));
    row.appendChild(
      DOM.div(
        { className: "col-sm-8 field-value" },
        result.error ? String(result.error) : String(result.value)
      )
    );
    section.appendChild(row);
  });
  displayDiv.append(section);
}
