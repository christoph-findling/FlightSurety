pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    FlightSuretyData flightSuretyData;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract

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
        // Modify to call data contract's status
        require(
            flightSuretyData.isOperational() == true,
            "Contract is currently not operational"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireFundedAirline() {
        require(isFundedAirline(msg.sender), "Caller is not a funded airline");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address contractAddress) public {
        flightSuretyData = FlightSuretyData(contractAddress);
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    function isFundedAirline(address airline) public view returns (bool) {
        return flightSuretyData.isFundedAirline(airline);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function setTestingMode(bool mode)
        external
        view
        requireIsOperational
        returns (bool)
    {
        return mode;
    }

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(address airlineAddress) public requireFundedAirline requireIsOperational returns (bool) {
        bool success = flightSuretyData.registerAirline(msg.sender, airlineAddress);
        return success;
    }

    function fundAirline() public payable requireIsOperational returns (bool) {
        bool success = flightSuretyData.fundAirline.value(msg.value)(
            msg.sender
        );
        return success;
    }

    function voteForAirline(address airlineAddress)
        public
        requireFundedAirline
        returns (bool)
    {
        bool success = flightSuretyData.voteForAirline(
            msg.sender,
            airlineAddress
        );
        return success;
    }

    /**
     * @dev Register a future flight for insuring.
    //  *
     */
    function registerFlight(string flight, uint256 timestamp)
        external
        view
        requireIsOperational
        requireFundedAirline
        returns (bool)
    {
        require(now < timestamp, "Time is in the past.");
        bool success = flightSuretyData.registerFlight(msg.sender, flight, timestamp);
        return success;
    }

    function buyInsurance(
        address airline,
        string flight,
        uint256 timestamp
    ) external payable returns (bool) {
        require(now < timestamp, "Flight already departed.");
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        bool success = flightSuretyData.buyInsurance.value(msg.value)(
            msg.sender,
            flightKey
        );
        return success;
    }

    function requestPayout() public returns (bool) {
        bool success = flightSuretyData.requestPayout(msg.sender);
        return success;
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode,
        address insuree
    ) internal view requireIsOperational {
        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            bytes32 flightKey = getFlightKey(airline, flight, timestamp);
            flightSuretyData.creditInsuree(insuree, flightKey);
        } else {
            flightSuretyData.cashInInsurance(insuree, flightKey);
        }
    }

    // Generate a request for oracles to fetch flight information | called by the UI
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    ) external {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        // Generate a unique key for storing the request
        uint8 index = getRandomIndex(msg.sender);
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );

        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond with the same status for valid status
    uint256 private constant MIN_RESPONSES = 1;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    event FlightStatusInfo(
        address airline,
        address requester,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired each time an oracle submits a response
    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle()
        external
        payable
        requireIsOperational
        returns (uint8[3])
    {
        // Require registration fee
        require(!oracles[msg.sender].isRegistered, "Already registered.");
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
        return indexes;
    }

    function getMyIndices() external view returns (uint8[3]) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external requireIsOperational {
        require(now > timestamp, "Flight has not departed yet.");
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        // require(
        //     oracleResponses[key].isOpen,
        //     "Flight or timestamp do not match oracle request or request got enough responses already."
        // );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        // emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >=
            MIN_RESPONSES &&
            oracleResponses[key].isOpen
        ) {
            oracleResponses[key].isOpen = false;
            emit FlightStatusInfo(
                airline,
                oracleResponses[key].requester,
                flight,
                timestamp,
                statusCode
            );
            // Handle flight status as appropriate
            processFlightStatus(
                airline,
                flight,
                timestamp,
                statusCode,
                oracleResponses[key].requester
            );
            bytes32 flightKey = getFlightKey(airline, flight, timestamp);
            flightSuretyData.updateFlightStatus(flightKey, statusCode);
        }
    }

    // Used for tracking requests, can be multiple
    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns random number between 0 and 9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}

contract FlightSuretyData {
    function registerAirline(address sender, address airlineAddress)
        external
        pure
        returns (bool)
    {}

    function isOperational() external pure returns (bool) {}

    function isFundedAirline(address airlineAddress)
        external
        pure
        returns (bool)
    {}

    function fundAirline(address airlineAddress)
        external
        payable
        returns (bool)
    {}

    function voteForAirline(address sender, address airlineAddress)
        external
        pure
        returns (bool)
    {}

    function registerFlight(address sender, string flight, uint256 timestamp)
        external
        returns (bool)
    {}

    function buyInsurance(address sender, bytes32 flightKey)
        external
        payable
        returns (bool)
    {}

    function hasInsuranceForFlight(address sender, bytes32 flightKey)
        external
        view
        returns (bool)
    {}

    function creditInsuree(address insuree, bytes32 flightKey)
        external
        returns (bool)
    {}

    function requestPayout(address sender) external view returns (bool) {}

    function cashInInsurance(address sender, bytes32 flightKey)
        external
        view
        returns (bool)
    {}

    function updateFlightStatus(bytes32 flightKey, uint8 statusCode)
        external
        view
        returns (bool)
    {}
}
