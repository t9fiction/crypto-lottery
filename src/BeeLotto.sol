// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract BeeLotto {
    address public owner;
    uint256 public ticketPrice = 10 * 10 ** 18; // 50 Bee tokens per ticket
    uint256 public maxTickets = 100; // maximum tickets per lottery
    uint256 public ticketCommission = 50 * 10 ** 16; // commission per ticket in Token
    uint256 public maxTicketsPerWallet = 15;
    uint256 public lottoDuration = 1440 minutes; // The duration set for the lottery 1 Day

    uint256 public operatorTotalCommission = 0; // Total commission balance
    address public lastWinner; // The last winner of the lottery
    uint256 public lastWinnerAmount; // The last winner amount of the lottery

    mapping(address => uint256) public winningAmount; // Maps the winners to their winnings
    address[] public ticketHolders; // Array of purchased tickets

    IERC20 public token; // ERC20 token contract
    address public erc20Token = 0xF53D495fC33cb402D005F77C08c203A690C62b46;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        token = IERC20(erc20Token);
    }

    // modifier to check if caller is a winner
    modifier onlyWinner() {
        require(isWinner(), "Caller is not a winner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }

    function setLottoTimer(uint256 _timeInMins) external onlyOwner returns (bool) {
        // Get the current block timestamp
        require(_timeInMins * 1 minutes >= 5 minutes, "Lotto Duration can't be less then 5 minutes");
        uint256 currentTimestamp = block.timestamp;
        uint256 lottoTimeDuration = _timeInMins * 1 minutes;
        lottoDuration = currentTimestamp + lottoTimeDuration;
        return true;
    }

    function returnLottoTimer() external view returns (uint256) {
        return lottoDuration;
    }

    // return all the ticketHolders
    function getTicketHolders() public view returns (address[] memory) {
        return ticketHolders;
    }

    function getWinningsForAddress(address _address) public view returns (uint256) {
        return winningAmount[_address];
    }

    function BuyTickets(uint256 _numOfTicketsToBuy) public {
        require(_numOfTicketsToBuy <= RemainingTickets(), "Not enough tickets available.");

        token.transferFrom(msg.sender, address(this), ticketPrice * _numOfTicketsToBuy);

        for (uint256 i = 0; i < _numOfTicketsToBuy; i++) {
            ticketHolders.push(msg.sender);
        }
    }

    function DrawWinnerTicket() public onlyOwner {
        require(ticketHolders.length > 0, "No tickets were purchased");

        bytes32 blockHash = blockhash(block.number - ticketHolders.length);
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, blockHash)));
        uint256 winningTicket = randomNumber % ticketHolders.length;

        address winner = ticketHolders[winningTicket];
        lastWinner = winner;
        winningAmount[winner] += (ticketHolders.length * (ticketPrice - ticketCommission));
        lastWinnerAmount = winningAmount[winner];
        operatorTotalCommission += (ticketHolders.length * ticketCommission);
        delete ticketHolders;
    }

    function checkWinningsAmount() public view returns (uint256) {
        address winner = msg.sender;

        uint256 rewardToTransfer = winningAmount[winner];

        return rewardToTransfer;
    }

    function WithdrawWinnings() public onlyWinner {
        address winner = msg.sender;

        uint256 rewardToTransfer = winningAmount[winner];
        winningAmount[winner] = 0;

        token.transfer(winner, rewardToTransfer);
    }

    function RefundAll() public onlyOwner {
        for (uint256 i = 0; i < ticketHolders.length; i++) {
            address to = ticketHolders[i];
            ticketHolders[i] = address(0);
            token.transfer(to, ticketPrice);
        }
        delete ticketHolders;
    }

    function WithdrawCommission() public onlyOwner {
        address operator = msg.sender;

        uint256 commissionToTransfer = operatorTotalCommission;
        operatorTotalCommission = 0;

        token.transfer(operator, commissionToTransfer);
    }

    function CurrentWinningReward() public view returns (uint256) {
        return ticketHolders.length * ticketPrice;
    }

    function RemainingTickets() public view returns (uint256) {
        return maxTickets - ticketHolders.length;
    }

    function isWinner() public view returns (bool) {
        return winningAmount[msg.sender] > 0;
    }

    //Function to change the price of TicketPrice
    function updateTicketPrice(uint256 _tokensPerTicket) public onlyOwner returns (bool) {
        ticketPrice = _tokensPerTicket * 10 ** 18;
        return true;
    }

    //Function to change the Max number of tickets for each lotto
    function updateMaxTickets(uint256 _maxTickets) public onlyOwner returns (bool) {
        maxTickets = _maxTickets;
        return true;
    }

    //Function to update the Ticket commission for each ticket
    function updateTicketCommission(uint256 _noOfTokensAsCommission) public onlyOwner returns (bool) {
        require(
            _noOfTokensAsCommission * 10 ** 16 < ticketPrice, "Commission can't be greater then the Price of the Ticket"
        );
        ticketCommission = _noOfTokensAsCommission * 10 ** 16;
        return true;
    }
}
