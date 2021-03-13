pragma solidity 0.8.0;

interface IERC20Lotto {
  function draw() external returns (bytes32);
  function enter(uint luckyNumber) external payable returns (bytes32);
  function startNewRound() external returns (bool);
}

contract Lotto is IERC20Lotto {

  string public name;
  address public feeRecipient;

  uint public constant ethDecimals = 1000000000000000000;
  uint public constant fee = 10000000000000000; // 1%

  constructor(uint _drawFrequency, uint _ticketPrice, string memory _name, address _feeRecipient) {
    drawFrequency = _drawFrequency*3600;
    ticketPrice = _ticketPrice*100000000000000000;
    name = _name;
    feeRecipient = _feeRecipient;
  }

  uint immutable drawFrequency;
  uint immutable ticketPrice;

  uint public currentLotto;
  uint public currentDraw;
  uint public ticketCounter;

  struct Lottery {
    uint startTime;
    uint lastDraw;

    uint totalPot;
    uint totalParticipants;

    bytes32 winningTicket;
    bool finished;
  }

  struct Ticket {
    address[] owners;
    uint ticketNumber;
  }

	mapping (uint => Lottery) lottos;

  //user-specific mappings per lotto
	mapping (bytes32 => Ticket) public tickets;
  mapping (uint => mapping(address => bool)) public hasEntered;
  mapping (address => uint) public debtToUser;

  function startNewRound() public override returns (bool) {
    require(lottos[currentLotto].finished, "previous lottery has not finished");
    currentLotto++;
    lottos[currentLotto] = Lottery(_timestamp(), _timestamp(), 0, 0, bytes32(0), false);
    return true;
  }

  function enter() public override payable returns (bytes32) {
    require (msg.value == ticketPrice, "Wrong amount.");
    require (lottos[currentLotto].finished = false, "a winner has already been selected. please start a new lottery.");

    uint payment = msg.value;

    ticketCounter++;
    lottos[currentLotto].totalPot += payment;

    if (hasEntered[currentLotto][_sender()] == false) {
      lottos[currentLotto].totalParticipants++;
    }

    bytes32 ticketID = createNewTicket();
    return ticketID;
  }

  function draw() public override returns (bytes32) {
    require (_timestamp() - lottos[currentLotto].lastDraw >= drawFrequency, "Not enough time elapsed from last draw");
    require (lottos[currentLotto].finished = false, "a winner has already been selected. please start a new lottery.");

    uint luckyNumber = generateRandomNumber();
    bytes32 winner = selectWinningTicket();

    if (winner == bytes32(0)) {
      lottos[currentLotto].lastDraw = _timestamp();
      currentDraw++;
      return bytes32(0);
    } else {
      payWinner(winner);
      currentDraw = 0;
      return winner;
    }
  }

  function payWinner(bytes32 _winner) internal returns (bool) {
    lottos[currentLotto].winningTicket = _winner;
    lottos[currentLotto].lastDraw = _timestamp();
    finalAccounting();
    return true;
  }

  function selectWinningTicket() internal view returns (bytes32) {

    uint winningNumber = generateTicketNumber();
    bytes32 winningID = generateTicketID(winningNumber);

    if (tickets[winningID].owners.length > 0) {
      return winningID;
    } else {
      return bytes32(0);
    }
  }

  function createNewTicket() internal returns (bytes32) {

    uint ticketNumber = generateTicketNumber();
    bytes32 _ticketID = generateTicketID(ticketNumber);

    if (tickets[_ticketID].owners.length > 0) {
      tickets[_ticketID].owners.push(_sender());
      return _ticketID;
    } else {
      address[] memory newOwner = new address[](1);
      newOwner[0] = _sender();
      tickets[_ticketID] = Ticket(newOwner, ticketNumber);
      return _ticketID;
    }
  }

  function finalAccounting() internal returns (bool) {
    require(!lottos[currentLotto].finished, "lottery is not finished");

    lottos[currentLotto].finished = true;
    bytes32 _winningTicket = lottos[currentLotto].winningTicket;
    address[] memory _winners = tickets[_winningTicket].owners;
    uint _winnerCount = _winners.length;

    uint winnings = calculateWinnings();
    debtToUser[feeRecipient] += lottos[currentLotto].totalPot - winnings;
    uint winningsPerUser = (winnings / _winnerCount);

    assert((winningsPerUser*_winnerCount) < lottos[currentLotto].totalPot);

    for (uint i; i < _winners.length; i++) {
      debtToUser[_winners[i]] += winningsPerUser;
    }
    return true;
  }

  function generateTicketNumber() internal view returns (uint _ticketNumber) {
    _ticketNumber = generateRandomNumber();
    return _ticketNumber;
  }

  function calculateWinnings() internal view returns (uint) {
    uint total = lottos[currentLotto].totalPot;
    uint _rake = feeCalc(total);
    uint _winnings = total - _rake;
    assert(_winnings < lottos[currentLotto].totalPot);
    return _winnings;
  }

  function generateTicketID(uint _ticketNumber) internal view returns (bytes32) {
    bytes32 _ticketID = keccak256(abi.encodePacked(currentLotto, currentDraw, _ticketNumber));
    return _ticketID;
  }

  function generateRandomNumber() internal view returns (uint) {
    return (uint(keccak256(abi.encodePacked(block.timestamp, block.number, ticketCounter))) % 10);
  }

  function viewTicket(bytes32 _ticketID) internal view returns (Ticket memory) {
    return tickets[_ticketID];
  }

	function feeCalc(uint _total) internal pure returns (uint) {
    uint _rake = (_total * fee) / ethDecimals;
    return(_rake);
  }

	function _sender() internal view returns (address) {
  	return msg.sender;
  }

  function _timestamp() internal view returns (uint) {
    return block.timestamp;
  }
}