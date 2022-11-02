pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    enum RegistrationStatus {
        Null, // enum will be initialized to 0 for non-existend entries
        Pending, // waiting for votes
        Registered, // waiting for funding
        Funded // end state
    }

    struct Airline {
        bool exists;
        RegistrationStatus status;
        uint256 votes;
    }

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false

    mapping(address => uint8) authorizedContracts;
    mapping(address => Airline) public airlines;
    // mapping(address => RegistrationStatus) public airlinesStatus;
    mapping(address => uint8[3]) airlinesIndexes;
    mapping(address => mapping(address => uint8)) registerAirlinesQueueVotes; // First address represents the airline in the registration queue, second address represents a registered airline that voted for the airline
    // mapping(address => uint256) registerAirlinesQueueVotesCount; // Counts the number of registration votes an airline has received
    uint256 fundedAirlinesCount = 0; // Total number of funded airlines
    uint256 minFundingValue = 10 ether;
    uint256 minInsuredAmount = 0.1 ether;
    uint256 maxInsuredAmount = 1 ether;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    mapping(bytes32 => mapping(address => uint)) private issuedInsurances; // flightKey => user => insured amount (up to 1 ether)
    mapping(address => uint) private passengerWallet; // stores the accumulated reimbursements of a user

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address firstAirline) public {
        airlines[firstAirline].exists = true;
        airlines[firstAirline].status = RegistrationStatus.Funded;
        fundedAirlinesCount += 1;
        contractOwner = msg.sender;
        authorizedContracts[msg.sender] = 1;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedContract() {
        require(
            authorizedContracts[msg.sender] == 1,
            "Caller is not authorized"
        );
        _;
    }

    function addAuthorizedContract(address contractToAdd)
        public
        requireContractOwner
    {
        authorizedContracts[contractToAdd] = 1;
    }

    function removeAuthorizedContract(address contractToRemove)
        public
        requireContractOwner
    {
        authorizedContracts[contractToRemove] = 0;
    }

    function authorizeCaller(address callerAddress)
        internal
        view
        returns (bool)
    {
        return authorizedContracts[callerAddress] == 1;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode)
        external
        requireContractOwner
        returns (bool)
    {
        require(operational != mode, "Operating status would not be changed");
        operational = mode;
        return operational;
    }

    function isAirline(address airline) public view returns (bool) {
        return airlines[airline].exists;
    }

    function isFundedAirline(address airline) public view returns (bool) {
        return airlines[airline].status == RegistrationStatus.Funded;
    }

    function hasInsuranceForFlight(address sender, bytes32 flightKey)
        external
        view
        requireAuthorizedContract
        requireIsOperational
        returns (bool)
    {
        return issuedInsurances[flightKey][sender] > 0;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address sender, address airlineAddress)
        external
        requireIsOperational
        requireAuthorizedContract
        returns (bool)
    {
        require(
            isFundedAirline(sender),
            "An airline can only be registered by a funded airline."
        );
        require(
            airlines[airlineAddress].status != RegistrationStatus.Registered,
            "Airline already registered."
        );
        require(
            airlines[airlineAddress].status != RegistrationStatus.Funded,
            "Airline has already been funded."
        );
        require(
            airlines[airlineAddress].status != RegistrationStatus.Pending,
            "Airline already waiting for votes."
        );
        if (fundedAirlinesCount < 4) {
            airlines[airlineAddress].exists = true;
            airlines[airlineAddress].status = RegistrationStatus.Registered;
            return true;
        } else {
            airlines[airlineAddress].status = RegistrationStatus.Pending;
            airlines[airlineAddress].exists = true;
            return true;
        }
    }

    function voteForAirline(address sender, address airlineAddress)
        external
        requireAuthorizedContract
        requireIsOperational
        returns (bool)
    {
        require(isFundedAirline(sender), "Must be funded airline to vote");
        require(airlines[airlineAddress].exists, "Airline does not exist");
        require(
            airlines[airlineAddress].status == RegistrationStatus.Pending,
            "Airline is not waiting for votes"
        );
        require(
            registerAirlinesQueueVotes[airlineAddress][sender] <= 0,
            "Already voted for airline"
        );
        registerAirlinesQueueVotes[airlineAddress][sender] = 1;
        airlines[airlineAddress].votes += 1;
        if (airlines[airlineAddress].votes > (fundedAirlinesCount / 2)) {
            airlines[airlineAddress].status = RegistrationStatus.Registered;
        }
        return true;
    }

    function registerFlight(
        address airlineAddress,
        string flight,
        uint256 timestamp
    ) external requireAuthorizedContract requireIsOperational returns (bool) {
        require(
            isFundedAirline(airlineAddress),
            "Must be funded airline to register flight"
        );
        bytes32 flightKey = getFlightKey(airlineAddress, flight, timestamp);
        require(!flights[flightKey].isRegistered, "Flight already registered");
        flights[flightKey] = Flight({
            isRegistered: true,
            airline: airlineAddress,
            updatedTimestamp: 0,
            statusCode: 0
        });
        return true;
    }

    function updateFlightStatus(bytes32 flightKey, uint8 statusCode)
        external
        requireAuthorizedContract
        requireIsOperational
        returns (bool)
    {
        require(flights[flightKey].isRegistered, "Not a registered flight");
        flights[flightKey].statusCode = statusCode;
        flights[flightKey].updatedTimestamp = now;
        return true;
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buyInsurance(address sender, bytes32 flightKey)
        external
        payable
        requireAuthorizedContract
        requireIsOperational
        returns (bool)
    {
        require(
            issuedInsurances[flightKey][sender] <= 0,
            "Already bought insurance for this flight."
        );
        require(flights[flightKey].isRegistered, "Flight not registered.");
        require(
            msg.value >= minInsuredAmount,
            "Amount must be greater than or equal to 0.1 ether"
        );
        if (msg.value > maxInsuredAmount) {
            issuedInsurances[flightKey][sender] = 1;
            sender.transfer(msg.value - maxInsuredAmount);
        } else {
            issuedInsurances[flightKey][sender] = msg.value;
        }
        return true;
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsuree(address insuree, bytes32 flightKey)
        external
        requireAuthorizedContract
        requireIsOperational
        returns (bool)
    {
        require(
            issuedInsurances[flightKey][insuree] > 0,
            "User has no insurance for the flightkey provided"
        );
        // Insuree is payed out 1.5x the amount he put in
        passengerWallet[insuree] += ((issuedInsurances[flightKey][insuree] *
            1500) / 1000);
        issuedInsurances[flightKey][insuree] = 0;
        return true;
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function requestPayout(address insuree)
        external
        requireIsOperational
        requireAuthorizedContract
        returns (bool)
    {
        require(passengerWallet[insuree] > 0, "No funds to pay out.");
        uint fundsToSend = passengerWallet[insuree];
        passengerWallet[insuree] = 0;
        require(
            address(this).balance >= fundsToSend,
            "Contract does not have enough funds"
        );
        insuree.transfer(fundsToSend);
        return true;
    }

    function cashInInsurance(address insuree, bytes32 flightKey)
        external
        requireAuthorizedContract
        requireIsOperational
        returns (bool)
    {
        issuedInsurances[flightKey][insuree] = 0;
        return true;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fundAirline(address airlineAddress)
        external
        payable
        requireAuthorizedContract
        requireIsOperational
        returns (bool)
    {
        require(
            airlines[airlineAddress].status == RegistrationStatus.Registered,
            "Airline is not at the funding stage."
        );
        require(
            msg.value >= minFundingValue,
            "Min. funding amount is 10 ether."
        );
        airlines[airlineAddress].status = RegistrationStatus.Funded;
        fundedAirlinesCount++;
        if (msg.value > minFundingValue) {
            airlineAddress.transfer(msg.value - minFundingValue);
        }
        return true;
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {}
}
