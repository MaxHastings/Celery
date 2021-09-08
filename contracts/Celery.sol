//SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

struct Account {
    // How much Celery is in the contract for a particular address
    uint256 amount; 
    // The last time (epoch) the contract processed calculating Account interest or payout.
    uint256 lastProcessedTime;
    // Remember the last staking balance when Account switches to payout. Used for calculating payout amount.
    uint256 lastStakingBalance;
    // The status of the account
    uint status; //0 = Payout, 1 = Staking
}

/// @title An Annuity like Smart Contract called Celery
/// @notice You can use this contract to stake and earn Celery
/// @dev Inherits ERC20 functionality
contract Celery is ERC20 {
    // Create key-value pair, key = address, value = Account struct
    mapping(address => Account) private _accounts;

    // 1 year is equal to in seconds. 60 sec * 60 min * 24 hr * 365 days = 31536000 seconds in a year.
    uint256 SECONDS_PER_YEAR = 31536000;

    // Contract creation
    constructor(uint256 initialSupply) ERC20("Celery", "CLY") {
        _mint(msg.sender, initialSupply); // Create initial supply
        approve(msg.sender, initialSupply); //Approves the initial supply for the sender to use
    }
    
    /*** Public read functions ***/

    /// @notice Retrieves the amount of tokens currently staked in an Account
    /// @param addr The address that is asssociated with the Account
    /// @return amount of staked tokens in the Account
    function getStakedAmount(address addr) public view returns (uint256) {
        return _accounts[addr].amount;
    }
    
    /// @notice Retrieves the last time the Account was updated.
    /// @param addr The address that is asssociated with the Account
    /// @return epoch time in seconds
    function getLastProcessedTime(address addr) public view returns (uint256) {
        return _accounts[addr].lastProcessedTime;
    }

    /// @notice Retrieves the last time the Account was updated.
    /// @param addr The address that is asssociated with the Account
    /// @dev Account status must be in payout for this data to be useful.
    /// @return epoch time in seconds
    function getLastStakingBalance(address addr) public view returns (uint256)
    {
        return _accounts[addr].lastStakingBalance;
    }

    /// @notice Retrieves the Account status, either Payout or Staking.
    /// @param addr The address that is asssociated with the Account
    /// @return status of Account, 0 = Payout, 1 = Staking
    function getStatus(address addr) public view returns (uint) {
        return _accounts[addr].status;
    }

    /*** ***/

    /*** Public write functions ***/

    /// @notice Switches Account status to start staking.
    /// @dev Check if already staking and if not, process an account payout then switch to staking.
    function StartStake() public {
        // Check if Account is already staking, return if true
        if (_isAccountInStake()) {
            return;
        }

        // Process an account payout before switching account to staking.
        _processNormalPayoutToAccount();

        // Set Account to start staking.
        _setAccountToStake();
    }

    /// @notice Transfer additional tokens to account balance and start staking.
    /// @param amount number of tokens to add to Account balance.
    function IncreaseBalanceAndStake(uint256 amount) public {
        // Check if amount is greater than zero.
        require(amount > 0, "Value must be greater than zero.");

        // Start staking if not already.
        StartStake();

        // Calculate interest on the current staked amount before adding additional tokens.
        _calculateStakedAmount();

        // Transfer additional tokens into smart contract balance.
        _transfer(msg.sender, address(this), amount);

        // Add the additional tokens to their Account balance.
        _accounts[msg.sender].amount += amount;
        
        // Notify that the account increased its token balance.
        emit IncreaseBalanceAndStakeEvent(msg.sender, amount);
    }

    /// @notice Switches Account status to start payout.
    function StartPayout() public {
        // Check if Account is already in payout, return if true
        if (_isAccountInPayout()) {
            return;
        }

        // Calculate interest on the current staked amount before switching account to payout.
        _calculateStakedAmount();

        // Set Account to start payout.
        _setAccountToPayout();

        uint256 currStakedNorm = _getAmount();
        // Remember last staking balance. Used later for calculating payout amount.
        _accounts[msg.sender].lastStakingBalance = currStakedNorm;
    }


    /// @notice Receive the tokens that are available for payout.
    function CollectPayout() public {

        // Start payout if not already
        StartPayout();

        // Process an account payout
        _processNormalPayoutToAccount();
    }

    /// @notice Force a payout amount to collect with up to a 50% penalty
    /// @param amount of tokens to collect from account
    function ForcePayout(uint256 amount) public {

        // Start payout if not already
        StartPayout();

        // Process an account payout
        uint256 normalPayoutAmount = _processNormalPayoutToAccount();

        // If normal payout amount is greater than or equal to what user wants to collect then return early.
        if (normalPayoutAmount >= amount) {
            return;
        }

        // Calculate the remaining number of tokens to force payout.
        uint256 penalizedAmountToCollect = amount - normalPayoutAmount;
        
        // Process a force payout amount for the remainder
        _processForcePayout(penalizedAmountToCollect);
    }

    /*** ***/

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
    */
    function _calculateStakedAmount() private {

        // Calculate the number of seconds that the Account has been staking for using block time.
        uint256 secondsStakedNorm = block.timestamp -
            _accounts[msg.sender].lastProcessedTime;

        // Get number of tokens Account is staking.
        uint256 currStakedNorm = _getAmount();

        // Update the time for last processed account
        _updateProcessedTime();

        // If seconds staked is zero or currnet amount staking is zero, return early.
        if (secondsStakedNorm == 0 || currStakedNorm == 0) {
            return;
        }

        // Convert seconds staked into fixed point number.
        uint256 secondsStaked = PRBMathUD60x18.fromUint(secondsStakedNorm);

        // APY 100% interest
        // APR 69.314..% continously compounded interest rate
        // Interest ratee is represented as a 60.18-decimal fixed-point number
        uint256 interest = 693147180559945309;
        // Euler's number represented as a 60.18-decimal fixed-point number
        uint256 euler = 2718281828459045235;
        // Calculate the percentage of the year staked. Ex. half year = 50% = 0.5
        uint256 percentageYearStaked = PRBMathUD60x18.div(
            secondsStaked,
            PRBMathUD60x18.fromUint(SECONDS_PER_YEAR)
        );

        // Convert staked amount into fixed point number. 
        uint256 currStaked = PRBMathUD60x18.fromUint(currStakedNorm);

        // Multiply interest rate by time staked
        uint256 rateTime = PRBMathUD60x18.mul(interest, percentageYearStaked);

        // Continuously compound the interest with euler's constant
        uint256 compoundedRate = PRBMathUD60x18.pow(euler, rateTime);

        // Multiple compounded rate with staked amount
        uint256 newAmount = PRBMathUD60x18.mul(currStaked, compoundedRate);
        
        // Round up for consistency
        uint256 newAmountCeil = PRBMathUD60x18.ceil(newAmount);

        // Convert new staked amount back to integer form.
        uint256 newAmountInt = PRBMathUD60x18.toUint(newAmountCeil);

        // Set new staked amount 
        _setAmount(newAmountInt);
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

    Returns token amount paid to account owner. Default is 0
    */
    function _processNormalPayoutToAccount() private returns(uint256) {
        // Get the latest block timestamp.
        uint256 timeStamp = block.timestamp;

        // Get the last time account was processed.
        uint256 lastTime = _accounts[msg.sender].lastProcessedTime;

        // Calculate the number of seconds account has been in payout for.
        uint256 timePassedInSecondsInt = timeStamp - lastTime;

        // Get the amount of tokens in Account balance.
        uint256 accountBalance = _getAmount();

        // Update the last time account was processed.
        _updateProcessedTime();

        // If time passed is zero or current balance amount is zero, end payout process early.
        if (timePassedInSecondsInt == 0 || accountBalance == 0) {
            return 0;
        }

        // Get Account last staking balance.
        uint256 payoutAmountSnapshotInt = _accounts[msg.sender].lastStakingBalance;

        // Convert Account last staking balance into fixed point decimal.
        uint256 payoutAmountSnapshot = PRBMathUD60x18.fromUint(
            payoutAmountSnapshotInt
        );

        // Set payout period to one year.
        uint256 payoutPeriodInSecondsInt = SECONDS_PER_YEAR;

        // Convert payout period into fixed point decimal.
        uint256 payoutPeriodInSeconds = PRBMathUD60x18.fromUint(
            payoutPeriodInSecondsInt
        );

        // Convert length of time to fixed point decimal.
        uint256 timePassedInSeconds = PRBMathUD60x18.fromUint(
            timePassedInSecondsInt
        );

        // Calculate percentage of the year that has passed. Ex. half year = 50% = 0.5
        uint256 payoutPeriodPercentage = PRBMathUD60x18.div(
            timePassedInSeconds,
            payoutPeriodInSeconds
        );

        // Multiply percentage of year with the last staking balance to calculate max payout.
        uint256 maxPayoutAmount = PRBMathUD60x18.mul(
            payoutPeriodPercentage,
            payoutAmountSnapshot
        );
        
        // Round max payout up
        uint256 maxPayoutAmountCeil = PRBMathUD60x18.ceil(maxPayoutAmount);

        // Convert max payout amount back to integer.
        uint256 maxPayoutAmountInt = PRBMathUD60x18.toUint(maxPayoutAmountCeil);

        uint256 payoutAmount = 0;

        // Check if Account Balance is smaller than max payout.
        if (accountBalance < maxPayoutAmountInt) {
            // Choose Account Balance if it is smaller.
            payoutAmount = accountBalance;
        } else {
            // Choose Max Payout Amount if it is smaller.
            payoutAmount = maxPayoutAmountInt;
        }

        // Send token payout.
        _payoutAmountToAccount(payoutAmount);

        // Subtract payout amount from Account balance.
        _accounts[msg.sender].amount -= payoutAmount;

        // Notify that an Account collected a payout.
        emit CollectPayoutEvent(msg.sender, payoutAmount);

        // Return payout amount.
        return payoutAmount;
    }

    /*
    Private Function
    Processes a forced payout with a 50% penalty.
    */
    function _processForcePayout(uint256 amount) private {

        // Get Account balance
        uint256 accountBalance = _getAmount();

        // Check if force payout of more than account balancee
        require(amount <= accountBalance, "Collect payout is larger than Account balance");

        // Subtract amount collected from account balance
        _setAmount(accountBalance - amount);
        // Update last time processsed account
        _updateProcessedTime();

        // Apply 50% penalty to payout amount
        uint256 payoutAmount = amount / 2;

        // Send payout.
        _payoutAmountToAccount(payoutAmount);
        
        // Notify that an account forced payout with amount.
        emit ForcePayoutEvent(msg.sender, payoutAmount);
    }

    /*
    Private Fucntion
    Sends Tokens to account address.
    */
    function _payoutAmountToAccount(uint256 amount) private {
        // Get how many tokens are in contract address.
        uint256 contractTokenHoldings = balanceOf(address(this));

        // Check if contract address has enough tokens to send.
        if (amount > contractTokenHoldings) {
            // If contract does not have enough tokens, mint more and ensure to increase allowance for the sender (since we aren't transfering any to them)
            _mint(msg.sender, amount);
            increaseAllowance(msg.sender, amount);
        } else {
            // If contract has enough tokens, transfer them.
            _transfer(address(this), msg.sender, amount);
        }
    }

    /*** Events ***/
    // Event that an account forced payout with a penalty
    event ForcePayoutEvent(
        address _address,
        uint256 _amount
    );
        
    // Event that an account collected payout
    event CollectPayoutEvent(
        address _address,
        uint256 _amount
    );
    
    // Event that an account increased its balance
    event IncreaseBalanceAndStakeEvent(
        address _address,
        uint256 _amount
    );
    
    // Event that an account status has been changed.
    event AccountStatusEvent(
        address _address,
        uint _value
    );

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

    function _getStatus() private view returns (uint) {
        return _accounts[msg.sender].status;
    }

    function _getAmount() private view returns (uint256) {
        return _accounts[msg.sender].amount;
    }
    
    function _setAccountToPayout() private {
        _setStatus(0);
        // Notify that account status is now paying out
        emit AccountStatusEvent(msg.sender, 0);
    }

    function _setAccountToStake() private {
        _setStatus(1);
        // Notify that account status is now staking
        emit AccountStatusEvent(msg.sender, 1);
    }

    function _setStatus(uint status) private {
        _accounts[msg.sender].status = status;
    }

    function _setAmount(uint256 amount) private {
        _accounts[msg.sender].amount = amount;
    }
}
