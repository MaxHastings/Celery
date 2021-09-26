//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

// Statuses
enum Status {
    PAYOUT,
    STAKE
}

//Amount Type
enum AmountType {
    TO_WALLET,
    FROM_ACCOUNT
}

struct Account {
    // The number of tokens in the Account balance
    uint256 balance;
    // The last time (epoch) the contract processed calculating Account interest or payout.
    uint256 lastProcessedTime;
    // Remember the last staking balance when Account switches to payout. Used for calculating payout amount.
    uint256 lastStakingBalance;
    // The status of the account
    Status status; //0 = Payout, 1 = Staking
}

/// @title An Annuity like Smart Contract called Celery
/// @notice You can use this contract to stake and earn Celery
/// @dev Inherits ERC20 functionality
contract Celery is ERC20 {
    // Create key-value pair, key = address, value = Account struct
    mapping(address => Account) private _accounts;

    // 1 year is equal to in seconds. 60 sec * 60 min * 24 hr * 365 days = 31536000 seconds in a year.
    uint256 private constant SECONDS_PER_YEAR = 31536000;

    // Max 256 Integer
    uint256 private constant MAX_INT = 2**256 - 1;

    // End time to earn interest
    uint256 private endInterestTime;

    // APY 100% interest
    // APR 69.314..% continously compounded interest rate
    // Interest rate is represented as a 60.18-decimal fixed-point number
    uint256 private constant INTEREST = 693147180559945309;
    // Euler's constant represented as a 60.18-decimal fixed-point number
    uint256 private constant EULER = 2718281828459045235;

    // Contract creation
    constructor(uint256 initialSupplyNorm) ERC20("Celery", "CLY") {
        _mint(msg.sender, initialSupplyNorm); // Create initial supply
        approve(msg.sender, initialSupplyNorm); //Approves the initial supply for the sender to use

        // Calculate the end time for when to stop interest
        uint256 initialSupply = PRBMathUD60x18.fromUint(initialSupplyNorm);
        uint256 compoundedInterest = PRBMathUD60x18.div(MAX_INT, initialSupply);
        uint256 rateTime = PRBMathUD60x18.ln(compoundedInterest);
        uint256 numberOfYears = PRBMathUD60x18.div(rateTime, INTEREST);
        uint256 numberOfYearsNorm = PRBMathUD60x18.toUint(numberOfYears);
        endInterestTime = block.timestamp + (numberOfYearsNorm * SECONDS_PER_YEAR);
    }

    /*** Public read functions ***/

    /// @notice Retrieves the end time when interest stops
    /// @return unix seconds for when interest ends
    function getEndInterestTime() public view returns (uint256) {
        return endInterestTime;
    }

    /// @notice Retrieves the amount of tokens currently in Account Balance
    /// @param addr The address that is asssociated with the Account
    /// @return amount of tokens in the Account
    function getAccountBalance(address addr) public view returns (uint256) {
        return _accounts[addr].balance;
    }

    /// @notice Retrieves the last time the Account was updated.
    /// @param addr The address that is asssociated with the Account
    /// @return epoch time in seconds
    function getLastProcessedTime(address addr) public view returns (uint256) {
        return _accounts[addr].lastProcessedTime;
    }

    /// @notice Retrieves what the last staking Account Balance was before payout mode started.
    /// @param addr The address that is asssociated with the Account
    /// @dev Account status must be in payout for this data to be useful.
    /// @return epoch time in seconds
    function getLastStakingBalance(address addr) public view returns (uint256) {
        return _accounts[addr].lastStakingBalance;
    }

    /// @notice Retrieves the Account status, either Payout or Staking.
    /// @param addr The address that is asssociated with the Account
    /// @return status of Account, 0 = Payout, 1 = Staking
    function getStatus(address addr) public view returns (uint8) {
        return uint8(_accounts[addr].status);
    }

    /*** ***/

    /*** Public write functions ***/

    /// @notice Switches Account status to start staking.
    /// @dev Check if already staking and if not, process an account payout then switch to staking.
    function startStake() public {
        // Check if Account is already staking
        require(_isAccountInPayout(), "Already in stake status.");

        _startStake();
    }

    /// @notice Transfer additional tokens to account balance and start staking.
    /// @param amount number of tokens to add to Account balance.
    function increaseBalanceAndStake(uint256 amount) public {
        // Check if amount is greater than zero.
        require(amount > 0, "Amount must be greater than 0.");

        // Start staking if not already.
        _startStake();

        // Calculate interest on the current staked amount before adding additional tokens.
        _calculateStakedAmount();

        // Transfer additional tokens into smart contract balance.
        _transfer(msg.sender, address(this), amount);

        // Add the additional tokens to their Account balance.
        _accounts[msg.sender].balance += amount;

        // Notify that the account increased its token balance.
        emit IncreaseBalanceAndStakeEvent(msg.sender, amount);
    }

    /// @notice Switches Account status to start payout.
    function startPayout() public {
        // Check if Account is already in payout
        require(_isAccountInStake(), "Already in payout status.");

        _startPayout();
    }

    /// @notice Receive the tokens that are available for payout.
    function collectPayout() public {
        // Make sure account is in payout before collecting.
        require(_isAccountInPayout(), "Account is staking.");

        // Process an account payout
        uint256 payout = _processPayoutToAccount();
        require(payout > 0, "Nothing to payout.");
    }

    /// @notice Force a payout amount to collect with up to a 50% penalty
    /// @param amount of tokens to collect from account
    /// @param amountType If 0, amount is what you want into your wallet (post-penalty). If 1, amount is what you want to take from your account (pre-penalty)
    function forcePayout(uint256 amount, AmountType amountType) public {
        // Check if amount is greater than zero.
        require(amount > 0, "Amount must be greater than 0.");

        // Start payout if not already
        _startPayout();

        // Process an account collect payout
        uint256 collectPayoutAmount = _processPayoutToAccount();

        // If payout amount is greater than or equal to what user wants to collect then return early.
        if (collectPayoutAmount >= amount) {
            return;
        }

        // Calculate the remaining number of tokens to force payout.
        uint256 penalizedAmountToCollect = amount - collectPayoutAmount;

        // If to wallet type, we double this amount (as it will later be penalized by 50%)
        // to ensure user receives this amount into their wallet
        if (amountType == AmountType.TO_WALLET) {
            penalizedAmountToCollect *= 2;
        }

        // Get Account balance
        uint256 accountBalance = _getBalance();

        // Check if force payout of more than account balancee
        require(penalizedAmountToCollect <= accountBalance, "Insufficient account balance");

        // Subtract amount collected from account balance
        _setBalance(accountBalance - penalizedAmountToCollect);
        // Update last time processsed account
        _updateProcessedTime();

        // Apply 50% penalty to payout amount
        uint256 forcePayoutAmount = penalizedAmountToCollect / 2;

        // Send payout.
        _payoutAmountToAccount(forcePayoutAmount);

        // Notify that an account forced payout with amount.
        emit ForcePayoutEvent(msg.sender, forcePayoutAmount);
    }

    /*** ***/

    function _startStake() private {
        if (_isAccountInStake()) {
            return;
        }

        // Process an account payout before switching account to staking.
        _processPayoutToAccount();

        // Set Account to start staking.
        _setStatus(Status.STAKE);
        // Notify that account status is now staking
        emit AccountStatusEvent(msg.sender, Status.STAKE);
    }

    function _startPayout() private {
        // Check if Account is already in payout, return if true
        if (_isAccountInPayout()) {
            return;
        }

        // Calculate interest on the current staked amount before switching account to payout.
        _calculateStakedAmount();

        // Set Account to start payout.
        _setStatus(Status.PAYOUT);
        // Notify that account status is now paying out
        emit AccountStatusEvent(msg.sender, Status.PAYOUT);

        // Remember last staking balance. Used later for calculating payout amount.
        uint256 currStakedNorm = _getBalance();
        _accounts[msg.sender].lastStakingBalance = currStakedNorm;
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
    APR = LN(2) = 0.69314...%
    APY = 100%
    */
    function _calculateStakedAmount() private {
        uint256 lastProcessedTime = _accounts[msg.sender].lastProcessedTime;

        // Update the time for last processed account
        _updateProcessedTime();

        uint256 interestTimeStamp = block.timestamp;
        // Prevent adding interest past the end interest time. ( Stops token supply overflows )
        if (interestTimeStamp > endInterestTime) {
            interestTimeStamp = endInterestTime;
        }

        if (lastProcessedTime > interestTimeStamp) {
            return;
        }

        // Calculate the number of seconds that the Account has been staking for using block time.
        uint256 secondsStakedNorm = interestTimeStamp - lastProcessedTime;

        // Get number of tokens Account is staking.
        uint256 currStakedNorm = _getBalance();

        // If seconds staked is zero or currnet amount staking is zero, return early.
        if (secondsStakedNorm == 0 || currStakedNorm == 0) {
            return;
        }

        // Convert seconds staked into fixed point number.
        uint256 secondsStaked = PRBMathUD60x18.fromUint(secondsStakedNorm);

        // Calculate the percentage of the year staked. Ex. half year = 50% = 0.5
        uint256 percentageYearStaked = PRBMathUD60x18.div(secondsStaked, PRBMathUD60x18.fromUint(SECONDS_PER_YEAR));

        // Multiply interest rate by time staked
        uint256 rateTime = PRBMathUD60x18.mul(INTEREST, percentageYearStaked);

        // Continuously compound the interest with euler's constant
        uint256 compoundedRate = PRBMathUD60x18.pow(EULER, rateTime);

        // Convert staked amount into fixed point number.
        uint256 currStaked = PRBMathUD60x18.fromUint(currStakedNorm);

        // Multiply compounded rate with staked amount
        uint256 newAmount = PRBMathUD60x18.mul(currStaked, compoundedRate);

        // Round up for consistency
        uint256 newAmountCeil = PRBMathUD60x18.ceil(newAmount);

        // Convert new staked amount back to integer form.
        uint256 newAmountInt = PRBMathUD60x18.toUint(newAmountCeil);

        // Set new staked amount
        _setBalance(newAmountInt);
    }

    /*
    Private Function
    Calculates and processes the payout back to the account address.
    Returns number of tokens paid back to account owner.
    */
    function _processPayoutToAccount() private returns (uint256) {
        // Get the latest block timestamp.
        uint256 timeStamp = block.timestamp;

        // Get the last time account was processed.
        uint256 lastTime = _accounts[msg.sender].lastProcessedTime;

        // Calculate the number of seconds account has been in payout for.
        uint256 timePassedInSecondsInt = timeStamp - lastTime;

        // Get the amount of tokens in Account balance.
        uint256 accountBalance = _getBalance();

        // Update the last time account was processed.
        _updateProcessedTime();

        // Get Account last staking balance.
        uint256 payoutAmountSnapshotInt = _accounts[msg.sender].lastStakingBalance;

        // Convert Account last staking balance into fixed point decimal.
        uint256 payoutAmountSnapshot = PRBMathUD60x18.fromUint(payoutAmountSnapshotInt);

        // Set payout period to one year.
        uint256 payoutPeriodInSecondsInt = SECONDS_PER_YEAR;

        // Convert payout period into fixed point decimal.
        uint256 payoutPeriodInSeconds = PRBMathUD60x18.fromUint(payoutPeriodInSecondsInt);

        // Convert length of time to fixed point decimal.
        uint256 timePassedInSeconds = PRBMathUD60x18.fromUint(timePassedInSecondsInt);

        // Calculate percentage of the year that has passed. Ex. half year = 50% = 0.5
        uint256 payoutPeriodPercentage = PRBMathUD60x18.div(timePassedInSeconds, payoutPeriodInSeconds);

        // Multiply percentage of year with the last staking balance to calculate max payout.
        uint256 maxPayoutAmount = PRBMathUD60x18.mul(payoutPeriodPercentage, payoutAmountSnapshot);

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

        if (payoutAmount > 0) {
            // Send token payout.
            _payoutAmountToAccount(payoutAmount);

            // Subtract payout amount from Account balance.
            _accounts[msg.sender].balance -= payoutAmount;

            // Notify that an Account collected a payout.
            emit CollectPayoutEvent(msg.sender, payoutAmount);
        }

        // Return payout amount.
        return payoutAmount;
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
            if (contractTokenHoldings > 0) {
                // Transfer all tokens in contract
                _transfer(address(this), msg.sender, contractTokenHoldings);
            }
            uint256 mintAmount = amount - contractTokenHoldings;
            // Mint more and ensure to increase allowance for the sender (since we aren't transfering any to them)
            _mint(msg.sender, mintAmount);
            increaseAllowance(msg.sender, mintAmount);
        } else {
            // If contract has enough tokens, transfer them.
            _transfer(address(this), msg.sender, amount);
        }
    }

    /*** Events ***/
    // Event that an account forced payout with a penalty
    event ForcePayoutEvent(address _address, uint256 _amount);

    // Event that an account collected payout
    event CollectPayoutEvent(address _address, uint256 _amount);

    // Event that an account increased its balance
    event IncreaseBalanceAndStakeEvent(address _address, uint256 _amount);

    // Event that an account status has been changed.
    event AccountStatusEvent(address _address, Status _value);

    /*** Helpers ***/
    function _updateProcessedTime() private {
        _accounts[msg.sender].lastProcessedTime = block.timestamp;
    }

    function _isAccountInPayout() private view returns (bool) {
        return _getStatus() == Status.PAYOUT;
    }

    function _isAccountInStake() private view returns (bool) {
        return _getStatus() == Status.STAKE;
    }

    function _getStatus() private view returns (Status) {
        return _accounts[msg.sender].status;
    }

    function _getBalance() private view returns (uint256) {
        return _accounts[msg.sender].balance;
    }

    function _setStatus(Status status) private {
        _accounts[msg.sender].status = status;
    }

    function _setBalance(uint256 amount) private {
        _accounts[msg.sender].balance = amount;
    }
}
