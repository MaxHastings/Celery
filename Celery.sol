//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

struct Account {
    uint256 stakedAmount;
    uint256 lastProcessedTime;
    uint256 payoutAmountSnapshot;
    int status; //0 = Payout, 1 = Staking
}
 
contract Celery is ERC20 {
    
    // Create key-value pair, key = address, value = Account struct
    mapping(address => Account) private _accounts;

    // Contract creation
    constructor(uint256 initialSupply) ERC20("Celery", "CLY") {
        _mint(msg.sender, initialSupply); // Create initial supply
        approve(msg.sender, initialSupply); //Approves the initial supply for the sender to use 
    }
    
    /*** Public read functions ***/

    // Returns how much Celery is staked within the contract for a particular address
    function getStakedAmount(address addr) public view returns (uint256)  {
        return _accounts[addr].stakedAmount;
    }
    
    // Returns the last time (epoch) the contract was processed (either as a payout or a stake write event)
    function getLastProcessedTime(address addr) public view returns (uint256) {
        return _accounts[addr].lastProcessedTime;
    }
    
    // If status = 0 (payout), this returns the total payout that is occuring
    function getPayoutAmountSnapshot(address addr) public view returns (uint256) {
        return _accounts[addr].payoutAmountSnapshot;
    }
    
    // Returns status of account (payout or stake phase)
    function getStatus(address addr) public view returns (int) {
        return _accounts[addr].status;
    }
    /*** ***/


    /*
    Public function
    Start the Staking Phase for Account.
    */
    function StartStake() public {
      // Check if Account is already in Stake phase, return early
      if (_isAccountInStake()) {
        return;
      }

      // If in payout phase, send to account what has been collected over the payout period
      _processPayoutToAccount();
      _setAccountToStake();
    }
    
    /*
    Public Function
    Add more tokens to your staking account.
    */
    function IncreaseStake(uint256 amount) public {
      // Check if amount is greater than zero.
      require(amount > 0, "Value must be greater than zero.");

      StartStake();
      // Calculate current staked amount based on time passed before adding new staked amount to balance
      _calculateStakedAmount();

      // Transfer tokens into smart contract balance.
      _transfer(msg.sender, address(this), amount);
      
      // Add additional tokens to staked balance.
      _accounts[msg.sender].stakedAmount += amount;
    }
    
    /*
    Public function
    Start the Payout Phase for Account.
    */
    function StartPayout() public {
      // Check if Account is already in Payout phase, return early
      if (_isAccountInPayout()) {
        return;
      }

      // Process Stake.
      _calculateStakedAmount();
      _setAccountToPayout();
      
      // Take a snapshot of staked amount. Used later for calculating payout amount.
      uint256 currStakedNorm = _accounts[msg.sender].stakedAmount;
      _accounts[msg.sender].payoutAmountSnapshot = currStakedNorm;
    }

    /*
    Public function
    Collect the payout to your account, if any has accumulated over the payout time period
    */
    function CollectPayout() public {
      StartPayout();
      _processPayoutToAccount();
    }

    /*** Helpers ***/
    function _updateProcessedTime() private {
      _accounts[msg.sender].lastProcessedTime = block.timestamp;
    }

    function _isAccountInPayout() private view returns (bool) {
        return _getStatus() == 0;
    }

    function _isAccountInStake() private view returns (bool) {
        return _getStatus() == 1;
    }
    
    function _getStatus() private view returns (int) {
        return _accounts[msg.sender].status;
    }

    function _setAccountToPayout() private {
        _setStatus(0);
    }

    function _setAccountToStake() private {
        _setStatus(1);
    }

    function _setStatus(int status) private {
        _accounts[msg.sender].status = status;
    }
    
    /*
    Private Function
    Calculates and adds the interest earned to the staked account balance.
    Formula used for calculating interest. Continously compounding interest.
    
    P * e^(r * t) = P(t)
    
    P = Princpal Sum
    P(t) = Value at time t
    t = length of time the interest is applied for
    r = Annual Interest Rate = APR
    e = Euler's Number = 2.718...
    APR = 0.69314...%
    APY = 100%
    
    Steps:
    
    1) Find out the length of time that has passed since the last time calculating interest for account.
    2) Use continously compounding formula to calculate the new Princpal sum.
    3) Save new Princpal sum to account and update the time since last calculation.
    
    */
    function _calculateStakedAmount() private {
      _updateProcessedTime();

      uint256 secondsStakedNorm = block.timestamp - _accounts[msg.sender].lastProcessedTime;
      uint256 currStakedNorm = _accounts[msg.sender].stakedAmount;

      // If Time passed is zero or Current Staked Amount is zero, end payout process early.
      if(secondsStakedNorm == 0 || currStakedNorm == 0) {
          return;
      }
      
      uint256 secondsStaked = PRBMathUD60x18.fromUint(secondsStakedNorm);
      
      // APY 100% interest
      // APR 69.314..% continously compounded interest rate
      // Interest represented as 60.18-decimal fixed-point number
      uint256 interest = 693147180559945309;
      // Euler's number represented as 60.18-decimal fixed-point number
      uint256 euler = 2718281828459045235;
      uint256 secondsPerYear = 31536000;
      uint256 percentageYearStaked = PRBMathUD60x18.div(secondsStaked, PRBMathUD60x18.fromUint(secondsPerYear));
      uint256 currStaked = PRBMathUD60x18.fromUint(currStakedNorm);
    
      uint256 rateTime = PRBMathUD60x18.mul(interest, percentageYearStaked);
      uint256 compoundedRate = PRBMathUD60x18.pow(euler, rateTime);
      uint256 newAmount = PRBMathUD60x18.mul(currStaked, compoundedRate);
      uint256 newAmountNorm = PRBMathUD60x18.toUint(newAmount);

      _accounts[msg.sender].stakedAmount = newAmountNorm;
    }
    
    
    /*
    Private Function
    Calculates and processes the payout back to the account address.
    
    Steps:
    
    1) Find out the length of time that has passed since the last time calculating payout for account.
    2) Calculate the max payout amount.
        a) Payout Percentage = Seconds Passed / Year In Seconds
        b) Max Payout Amount = Payout Percentage * Staked Amount snapshot
    3) Send either Max Payout Amount or Current Staked Amount whichever is smaller to the Account address.
    4) Update Account last calculation time and subtract payout amount from account staked amount.
        
    */
    function _processPayoutToAccount() private {
      _updateProcessedTime();

      // Get the latest block timestamp.
      uint256 timeStamp = block.timestamp;
      
      // Get the last time account payout was processed.
      uint256 lastTime = _accounts[msg.sender].lastProcessedTime;
      
      // Calculate the length of time that has passed.
      uint256 timePassedInSecondsNorm = timeStamp - lastTime;
      uint256 currStakedNorm = _accounts[msg.sender].stakedAmount;
      
      // If Time passed is zero or Current Staked Amount is zero, end payout process early.
      if (timePassedInSecondsNorm == 0 || currStakedNorm == 0) {
          return;
      }
        
      // Get Account Payout Snapshot Amount.
      uint256 payoutAmountSnapshotNorm = _accounts[msg.sender].payoutAmountSnapshot;
      
      // Convert Account Payout Snapshot Amount into Fixed Point Decimal.
      uint256 payoutAmountSnapshot = PRBMathUD60x18.fromUint(payoutAmountSnapshotNorm);
      
      // 1 year payout period in seconds. 60 * 60 * 24 * 365 = 31536000 seconds in a year.
      uint256 payoutPeriodInSecondsNorm = 31536000;
      
      // Convert Payout Period into Fixed Point Decimal.
      uint256 payoutPeriodInSeconds = PRBMathUD60x18.fromUint(payoutPeriodInSecondsNorm);
      
      // Convert length of time to Fixed Point Decimal.
      uint256 timePassedInSeconds = PRBMathUD60x18.fromUint(timePassedInSecondsNorm);
      
      // Calculate percentage of the year that has passed.
      uint256 payoutPeriodPercentage = PRBMathUD60x18.div(timePassedInSeconds, payoutPeriodInSeconds);
      
      // Multiply percentage of year with the payout staked snapshot amount.
      uint256 maxPayoutAmount = PRBMathUD60x18.mul(payoutPeriodPercentage, payoutAmountSnapshot);
      
      // Convert payout amount back to normal integer.
      uint256 maxPayoutAmountNorm = PRBMathUD60x18.toUint(maxPayoutAmount);
    
      uint256 payoutAmount = 0;
      
      // Check if Current Staked Amount is smaller than Max Payout
      if (currStakedNorm < maxPayoutAmountNorm) {
        // Choose Current Staked Amount if it is smaller.
        payoutAmount = currStakedNorm;
      }
      else {
        // Choose Max Payout Amount if it is smaller.
        payoutAmount = maxPayoutAmountNorm;
      }
      
      // Send tokens to account address.
      _payoutAmountToAccount(payoutAmount);
      
      // Subtract payout amount from staked amount.
      _accounts[msg.sender].stakedAmount -= payoutAmount;
    }
    
    /*
    Private Fucntion
    Sends Tokens to account address.
    */
    function _payoutAmountToAccount(uint256 amount) private {
        // Get how many tokens are in contract address.
        uint256 contractTokenHoldings = balanceOf(address(this));
        
        // Check if contract address has enough tokens to send.
        if(amount > contractTokenHoldings) {
            // If contract does not have enough tokens, mint more.
            _mint(msg.sender, amount);
            increaseAllowance(msg.sender, amount);
        } else {
            // If contract has enough tokens, transfer them.
            _transfer(address(this), msg.sender, amount);
        }
    }
}
