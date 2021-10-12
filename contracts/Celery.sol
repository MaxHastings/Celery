//SPDX-License-Identifier: GPL-3.0

// Locked to specific version
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

/// @title An Annuity like Smart Contract called Celery
/// @notice You can use this contract to stake and earn Celery
/// @dev Inherits ERC20 functionality
contract Celery is ERC20 {
    /*** Type Declarations ***/

    // Each account can be in one status, payout or stake
    enum AccountStatus {
        PAYOUT,
        STAKE
    }

    // Two types of amounts can be specified for the "forcePayout" method
    // If TO_WALLET, amount is what you want into your wallet (post-penalty)
    // If FROM_ACCOUNT, amount is what you want to take from your account (pre-penalty)
    enum AmountType {
        TO_WALLET,
        FROM_ACCOUNT
    }

    // Each address that interacts with the contract will store the below data
    struct Account {
        // The number of tokens in the Account balance
        uint256 balance;
        // The last time (epoch) the contract processed calculating Account interest or payout
        uint256 lastProcessedTime;
        // Remember the last staking balance when Account switches to payout. Used for calculating payout amount
        uint256 lastStakingBalance;
        // The status of the account
        AccountStatus status; //0 = Payout, 1 = Staking
    }

    /*** ***/

    /*** State Variables ***/

    // Create key-value pair, key = address, value = Account struct
    mapping(address => Account) private _accounts;

    // 1 year is equal to in seconds. 60 sec * 60 min * 24 hr * 365 days = 31536000 seconds in a year
    uint256 private constant SECONDS_PER_YEAR = 31536000;

    // Max 256 bit Integer
    uint256 private constant MAX_256_UINT = 2**256 - 1;

    // End time to earn interest
    uint256 private immutable _endInterestTime;

    // The total number of tokens staking
    uint256 private _totalStakingSupply = 0;

    // The last processed time for total staking supply
    uint256 private _totalStakingTime = 0;

    // The total number of tokens in payout
    uint256 private _totalPayoutSupply = 0;

    // Two represented as a 60.18-decimal fixed-point number
    uint256 private constant TWO_FIXED_POINT = 2000000000000000000;

    // Repeated constant strings for requires
    string private constant TIMESTAMP_TOO_EARLY = "Timestamp too early.";
    string private constant ACCOUNT_IS_STAKING = "Account is staking.";
    string private constant AMOUNT_IS_0 = "Amount must be greater than 0.";
    string private constant INSUFFICIENT_ACCOUNT_BALANCE = "Insufficient account balance.";

    /*** ***/

    /*** Events ***/

    // Event that an account forced payout with a penalty
    event ForcePayoutEvent(address _address, uint256 _amount);

    // Event that an account collected payout
    event CollectPayoutEvent(address _address, uint256 _amount);

    // Event that an account increased its balance
    event IncreaseBalanceAndStakeEvent(address _address, uint256 _amount);

    // Event that an account status has been changed.
    event AccountStatusEvent(address _address, uint8 _value);

    /*** ***/

    // Contract creation
    constructor(uint256 initialSupplyNorm) ERC20("Celery", "CLY") {
        // Create initial supply
        _mint(msg.sender, initialSupplyNorm);

        //Approves the initial supply for the sender to use
        bool success = approve(msg.sender, initialSupplyNorm);
        require(success, "'approve' failure");

        // Calculate the end time for when to stop interest
        uint256 initialSupply = PRBMathUD60x18.fromUint(initialSupplyNorm);
        uint256 compoundedInterest = PRBMathUD60x18.div(MAX_256_UINT, initialSupply);
        uint256 numberOfYears = PRBMathUD60x18.log2(compoundedInterest);
        uint256 numberOfYearsNorm = PRBMathUD60x18.toUint(numberOfYears);

        // solhint-disable-next-line not-rely-on-time
        _endInterestTime = block.timestamp + (numberOfYearsNorm * SECONDS_PER_YEAR);

        // solhint-disable-next-line not-rely-on-time
        _totalStakingTime = block.timestamp;
    }

    /*** Public read functions ***/

    /// @notice Retrieves the amount of tokens currently in Account Balance
    /// @param addr The address that is asssociated with the Account
    /// @return Amount of tokens in the Account
    function getAccountBalance(address addr) public view returns (uint256) {
        return _accounts[addr].balance;
    }

    /// @notice Retrieves the last time the Account was updated
    /// @param addr The address that is asssociated with the Account
    /// @return Epoch time in seconds
    function getLastProcessedTime(address addr) public view returns (uint256) {
        return _accounts[addr].lastProcessedTime;
    }

    /// @notice Retrieves what the last staking Account Balance was before payout mode started
    /// @param addr The address that is asssociated with the Account
    /// @dev Account status must be in payout for this data to be useful
    /// @return Epoch time in seconds
    function getLastStakingBalance(address addr) public view returns (uint256) {
        return _accounts[addr].lastStakingBalance;
    }

    /// @notice Retrieves the Account status, either Payout or Staking
    /// @param addr The address that is asssociated with the Account
    /// @return Status of Account, 0 = Payout, 1 = Staking
    function getStatus(address addr) external view returns (uint8) {
        return uint8(_accounts[addr].status);
    }

    /// @notice Retrieves the end time when interest stops
    /// @return Epoch time in seconds
    function getEndInterestTime() external view returns (uint256) {
        return _endInterestTime;
    }

    /// @notice Retrieves the circulating token supply excluding staking and payout tokens
    /// @return Circulating token supply amount
    function getCirculatingSupply() public view returns (uint256) {
        return totalSupply() - balanceOf(address(this));
    }

    /// @notice Calculates and returns the total token staking supply
    /// @return Total staking supply amount
    function getTotalStakingSupply() public view returns (uint256) {
        uint256 secondsStaked = _getStakingTimestamp() - _totalStakingTime;
        return _calculateInterest(_totalStakingSupply, secondsStaked);
    }

    /// @notice Retrieves the total payout supply
    /// @return Total payout supply amount
    function getTotalPayoutSupply() external view returns (uint256) {
        return _totalPayoutSupply;
    }

    /// @notice Retrieves the fully dilulted token supply which includes all staking and payout tokens
    /// @return Fully Diluted token supply amount
    function getFullyDilutedSupply() external view returns (uint256) {
        return getCirculatingSupply() + getTotalStakingSupply() + _totalPayoutSupply;
    }

    /// @notice Allows you to estimate how much is available to collect from your account penalty-free at a specific point in time if you remain in payout status
    /// @param addr The address that is asssociated with the Account
    /// @param timeStamp The future timestamp of the planned collection time
    /// @return The Celery you would collect if you executed a collect payout at the provided timestamp
    function estimateCollectPayout(address addr, uint256 timeStamp) external view returns (uint256) {
        require(_isAccountInPayout(), ACCOUNT_IS_STAKING);

        // Get the last time account was processed.
        uint256 lastProcessedTime = getLastProcessedTime(addr);

        // Timestamp must be later or equal to when payout started
        require(timeStamp >= lastProcessedTime, TIMESTAMP_TOO_EARLY);

        // Run the calculation
        return _calculatePayoutToAccount(addr, timeStamp);
    }

    /// @notice Allows you to estimate how much you will earn at a specific point in time if you remain in stake status
    /// @param addr The address that is asssociated with the Account
    /// @param timeStamp The future timestamp to determine how much celery you would have at that point in time
    /// @return The Celery you would have if you kept staking up until the provided timestamp
    function estimateStakeBalance(address addr, uint256 timeStamp) external view returns (uint256) {
        require(_isAccountInStake(), "Account is in payout.");

        // Get the last time account was processed.
        uint256 lastProcessedTime = getLastProcessedTime(addr);

        // Timestamp must be later or equal to when stake started
        require(timeStamp >= lastProcessedTime, TIMESTAMP_TOO_EARLY);

        // Run the calculation on what would be staked at certain time
        return _calculateStakedAmount(addr, timeStamp, lastProcessedTime);
    }

    /// @notice Allows you to estimate how much of a penalty will be taken against your account based on the amount you withdraw at the future timestamp you pass in
    /// @param addr The address that is asssociated with the Account
    /// @param amount of tokens to collect from account
    /// @param amountType If 0, amount is what you want into your wallet (post-penalty). If 1, amount is what you want to take from your account (pre-penalty)
    /// @param timeStamp The future timestamp of an estimated force payout penalty action
    /// @return The Celery that would be destroyed during the force payout action
    function estimateForcePayoutPenaltyFee(
        address addr,
        uint256 amount,
        AmountType amountType,
        uint256 timeStamp
    ) external view returns (uint256) {
        require(amount > 0, AMOUNT_IS_0);

        // Get the last time account was processed
        uint256 lastProcessedTime = getLastProcessedTime(addr);

        // Timestamp must be later or equal to when payout/stake started
        require(timeStamp >= lastProcessedTime, TIMESTAMP_TOO_EARLY);

        // Calculate an account collect payout
        uint256 collectPayoutAmount = _calculatePayoutToAccount(addr, timeStamp);

        // The amount that will be subtracted from account balance
        uint256 penalizedAmountToCollect = _calculatePenalty(collectPayoutAmount, amount, amountType);

        uint256 accountBalance = getAccountBalance(addr);

        // Check if force payout (along with the normal collect) is more than account balance
        require(penalizedAmountToCollect + collectPayoutAmount <= accountBalance, INSUFFICIENT_ACCOUNT_BALANCE);

        // Apply 50% penalty to amount (which in turn gives us the penalty itself)
        uint256 penaltyAmount = penalizedAmountToCollect / 2;

        return penaltyAmount;
    }

    /*** ***/

    /*** Public write functions ***/

    /// @notice Switches Account status to start staking
    /// @dev Check if already staking and if not, process an account payout then switch to staking
    function startStake() external {
        require(_isAccountInPayout(), "Account already staking.");

        _startStake();
    }

    /// @notice Transfer additional tokens to account balance and start staking
    /// @param amount Number of tokens to add to Account balance
    function increaseBalanceAndStake(uint256 amount) external {
        require(amount > 0, AMOUNT_IS_0);

        // Start staking if not already
        _startStake();

        // Calculate interest on the current staked amount before adding additional tokens
        _processStakedAmount();

        // Transfer additional tokens into smart contract balance
        _transfer(msg.sender, address(this), amount);

        // Add the additional tokens to their Account balance
        _accounts[msg.sender].balance += amount;

        // Process total staking supply before adding to it
        _processTotalStakingSupply();

        // Add account balance to total staking supply
        _totalStakingSupply += amount;

        // Notify that the account increased its token balance
        emit IncreaseBalanceAndStakeEvent(msg.sender, amount);
    }

    /// @notice Switches Account status to start payout
    function startPayout() external {
        require(_isAccountInStake(), "Account already in payout.");

        _startPayout();
    }

    /// @notice Receive the tokens that are available for payout. There is no penalty on collected tokens
    function collectPayout() external {
        require(_isAccountInPayout(), ACCOUNT_IS_STAKING);

        // Process an account payout
        uint256 payout = _processPayoutToAccount();

        // Require payout to be greater than 0, otherwise no state would be changed
        require(payout > 0, "Nothing to payout.");
    }

    /// @notice Force a payout amount to collect with up to a 50% penalty
    /// @param amount of tokens to collect from account
    /// @param amountType If 0, amount is what you want into your wallet (post-penalty). If 1, amount is what you want to take from your account (pre-penalty)
    function forcePayout(uint256 amount, AmountType amountType) external {
        require(amount > 0, AMOUNT_IS_0);

        // Start payout if not already
        _startPayout();

        // Process an account collect payout
        uint256 collectPayoutAmount = _processPayoutToAccount();

        // The amount that will be subtracted from account balance
        uint256 penalizedAmountToCollect = _calculatePenalty(collectPayoutAmount, amount, amountType);

        // Nothing else to payout, return (collect payout covered the request)
        if (penalizedAmountToCollect == 0) {
            return;
        }

        // Get Account balance
        uint256 accountBalance = _getBalance();

        // Check if force payout is more than account balance
        require(penalizedAmountToCollect <= accountBalance, INSUFFICIENT_ACCOUNT_BALANCE);

        // Subtract amount with penalty from account balance
        _setBalance(accountBalance - penalizedAmountToCollect);

        // Subtract penalized amount from total payout supply
        _totalPayoutSupply -= penalizedAmountToCollect;

        // Update last time processsed account
        _updateProcessedTime();

        // Apply 50% penalty to payout amount (penalty is destroyed)
        uint256 forcePayoutAmount = penalizedAmountToCollect / 2;

        // Send payout
        _payoutAmountToAccount(forcePayoutAmount);

        // Notify that an account forced payout with amount
        emit ForcePayoutEvent(msg.sender, forcePayoutAmount);
    }

    /*** ***/

    /*** Private functions ***/

    // Get the current block timestamp with end interest time being the upper limit
    function _getStakingTimestamp() private view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        uint256 timeStamp = block.timestamp;

        // Prevent adding interest past the end interest time ( Stops token supply overflows )
        if (timeStamp > _endInterestTime) {
            timeStamp = _endInterestTime;
        }

        return timeStamp;
    }

    // Calculate and save the total staking supply interest.
    function _processTotalStakingSupply() private {
        uint256 timeStamp = _getStakingTimestamp();

        // If last processed time is equal to or greater than current time, return
        if (_totalStakingTime >= timeStamp) {
            return;
        }

        uint256 secondsStaked = timeStamp - _totalStakingTime;

        _totalStakingSupply = _calculateInterest(_totalStakingSupply, secondsStaked);

        // solhint-disable-next-line not-rely-on-time
        _totalStakingTime = block.timestamp;
    }

    function _startStake() private {
        if (_isAccountInStake()) {
            return;
        }

        // Process an account payout before switching account to staking
        _processPayoutToAccount();

        // Set Account to start staking
        _setStatus(AccountStatus.STAKE);

        // Process Total Staking supply before adding to it
        _processTotalStakingSupply();
        uint256 accountBalance = _getBalance();

        // Subtract account balance from total payout supply
        _totalPayoutSupply -= accountBalance;

        // Add account balance to total staking supply
        _totalStakingSupply += accountBalance;

        // Notify that account status is now staking
        emit AccountStatusEvent(msg.sender, uint8(AccountStatus.STAKE));
    }

    function _startPayout() private {
        // Check if Account is already in payout, return if true
        if (_isAccountInPayout()) {
            return;
        }

        // Calculate interest on the current staked amount before switching account to payout
        _processStakedAmount();

        // Set Account to start payout
        _setStatus(AccountStatus.PAYOUT);

        // Notify that account status is now paying out
        emit AccountStatusEvent(msg.sender, uint8(AccountStatus.PAYOUT));

        // Remember last staking balance. Used later for calculating payout amount
        uint256 currStakedNorm = _getBalance();
        _accounts[msg.sender].lastStakingBalance = currStakedNorm;

        // Process Total Staking supply before subtracing from it
        _processTotalStakingSupply();

        // Remove Account Balance from staking supply
        _totalStakingSupply -= currStakedNorm;

        // Add Account Balance to payout Supply
        _totalPayoutSupply += currStakedNorm;
    }

    /*
    Calculates and adds the interest earned to the staked account balance
    Formula used for calculating interest. Continously compounding interest
    Returns amount that user would have at the current timestamp
    */
    function _calculateStakedAmount(
        address addr,
        uint256 timeStamp,
        uint256 lastProcessedTime
    ) private view returns (uint256) {
        // Prevent adding interest past the end interest time. ( Stops token supply overflows )
        if (timeStamp > _endInterestTime) {
            timeStamp = _endInterestTime;
        }

        // Get number of tokens Account is staking
        uint256 currStakedNorm = getAccountBalance(addr);

        // If last processed time is equal to or greater than current time, return account balance
        if (lastProcessedTime >= timeStamp) {
            return currStakedNorm;
        }

        // Calculate the number of seconds that the Account has been staking for using block time
        uint256 secondsStakedNorm = timeStamp - lastProcessedTime;

        // If seconds staked is zero or currnet amount staking is zero, return account balance
        if (secondsStakedNorm == 0 || currStakedNorm == 0) {
            return currStakedNorm;
        }

        // Convert seconds staked into fixed point number
        uint256 newAmountInt = _calculateInterest(currStakedNorm, secondsStakedNorm);

        return newAmountInt;
    }

    /*
    Calculates the new staking balance which is composed of the current staked balance plus the interest earned over the number of seconds staked.
    
    P * e^(r * t) = P(t)
    
    P = Princpal Sum
    P(t) = Value at time t
    t = length of time the interest is applied for
    r = Annual Interest Rate = APR
    e = Euler's Number = 2.718...
    APR = LN(2) = 0.69314...%
    APY = 100%

    P(t) = P * e^(LN(2) * t) =  P * 2^t
    
    Returns the current staked balance + interest
    */
    function _calculateInterest(uint256 stakedAmountNorm, uint256 secondsStakedNorm) private pure returns (uint256) {
        // Convert seconds staked into fixed point number
        uint256 secondsStaked = PRBMathUD60x18.fromUint(secondsStakedNorm);

        // Calculate the percentage of the year staked. Ex. half year = 50% = 0.5
        uint256 percentageYearStaked = PRBMathUD60x18.div(secondsStaked, PRBMathUD60x18.fromUint(SECONDS_PER_YEAR));

        // Continuously compound the interest with 2^t
        uint256 compoundedRate = PRBMathUD60x18.pow(TWO_FIXED_POINT, percentageYearStaked);

        // Convert staked amount into fixed point number
        uint256 currStaked = PRBMathUD60x18.fromUint(stakedAmountNorm);

        // Multiply compounded rate with staked amount
        uint256 newAmount = PRBMathUD60x18.mul(currStaked, compoundedRate);

        // Round up, to give user benefit of doubt with time
        uint256 newAmountCeil = PRBMathUD60x18.ceil(newAmount);

        // Convert new staked amount back to integer form
        uint256 newAmountInt = PRBMathUD60x18.toUint(newAmountCeil);

        return newAmountInt;
    }

    /*
    State change function that runs the calculation stake function and commits it to the caller's account
    Returns nothing
    */
    function _processStakedAmount() private {
        uint256 lastProcessedTime = getLastProcessedTime(msg.sender);

        // Update the time for last processed account
        _updateProcessedTime();

        // Run the calculation on what has been earned from the stake at current time
        // solhint-disable-next-line not-rely-on-time
        uint256 newAmountInt = _calculateStakedAmount(msg.sender, block.timestamp, lastProcessedTime);

        if (newAmountInt > 0) {
            // Set new staked amount
            _setBalance(newAmountInt);
        }
    }

    /*
    State change function that runs the calculation payout function and commits it to the caller's account
    Returns number of tokens paid back to account owner
    */
    function _processPayoutToAccount() private returns (uint256) {
        // Calculate an account collect payout
        // solhint-disable-next-line not-rely-on-time
        uint256 payoutAmount = _calculatePayoutToAccount(msg.sender, block.timestamp);

        // Update the last time account was processed
        _updateProcessedTime();

        if (payoutAmount > 0) {
            // Send token payout
            _payoutAmountToAccount(payoutAmount);

            // Subtract payout amount from Account balance
            _accounts[msg.sender].balance -= payoutAmount;

            // Subtract payout amount from total payout supply
            _totalPayoutSupply -= payoutAmount;

            // Notify that an Account collected a payout
            emit CollectPayoutEvent(msg.sender, payoutAmount);
        }

        // Return payout amount.
        return payoutAmount;
    }

    /*
    Calculates and processes the payout back to the account address
    Returns number of tokens paid back to account owner
    */
    function _calculatePayoutToAccount(address addr, uint256 timeStamp) private view returns (uint256) {
        // Get the last time account was processed
        uint256 lastTime = getLastProcessedTime(addr);

        // Calculate the number of seconds account has been in payout for
        uint256 timePassedInSecondsInt = timeStamp - lastTime;

        // Get the amount of tokens in Account balance
        uint256 accountBalance = _getBalance();

        // Get Account last staking balance
        uint256 payoutAmountSnapshotInt = getLastStakingBalance(addr);

        // Convert Account last staking balance into fixed point decimal
        uint256 payoutAmountSnapshot = PRBMathUD60x18.fromUint(payoutAmountSnapshotInt);

        // Set payout period to one year
        uint256 payoutPeriodInSecondsInt = SECONDS_PER_YEAR;

        // Convert payout period into fixed point decimal
        uint256 payoutPeriodInSeconds = PRBMathUD60x18.fromUint(payoutPeriodInSecondsInt);

        // Convert length of time to fixed point decimal
        uint256 timePassedInSeconds = PRBMathUD60x18.fromUint(timePassedInSecondsInt);

        // Calculate percentage of the year that has passed. Ex. half year = 50% = 0.5
        uint256 payoutPeriodPercentage = PRBMathUD60x18.div(timePassedInSeconds, payoutPeriodInSeconds);

        // Multiply percentage of year with the last staking balance to calculate max payout
        uint256 maxPayoutAmount = PRBMathUD60x18.mul(payoutPeriodPercentage, payoutAmountSnapshot);

        // Round up, to give user benefit of doubt with time
        uint256 maxPayoutAmountCeil = PRBMathUD60x18.ceil(maxPayoutAmount);

        // Convert max payout amount back to integer
        uint256 maxPayoutAmountInt = PRBMathUD60x18.toUint(maxPayoutAmountCeil);

        uint256 payoutAmount = 0;

        // Check if Account Balance is smaller than max payout
        if (accountBalance < maxPayoutAmountInt) {
            // Choose Account Balance if it is smaller
            payoutAmount = accountBalance;
        } else {
            // Choose Max Payout Amount if it is smaller
            payoutAmount = maxPayoutAmountInt;
        }

        return payoutAmount;
    }

    /*
    Sends Tokens to account address.
    Returns nothing.
    */
    function _payoutAmountToAccount(uint256 amount) private {
        // Get how many tokens are in contract address
        uint256 contractTokenHoldings = balanceOf(address(this));

        // Check if contract address has enough tokens to send
        if (amount > contractTokenHoldings) {
            if (contractTokenHoldings > 0) {
                // Transfer all tokens in contract
                _transfer(address(this), msg.sender, contractTokenHoldings);
            }
            uint256 mintAmount = amount - contractTokenHoldings;
            // Mint more and ensure to increase allowance for the sender (since we aren't transfering any to them)
            _mint(msg.sender, mintAmount);
            bool success = increaseAllowance(msg.sender, mintAmount);
            require(success, "'increaseAllowance' failure");
        } else {
            // If contract has enough tokens, transfer them
            _transfer(address(this), msg.sender, amount);
        }
    }

    /*
    Calculates the penalty amount that will be applied to the user for a force payout
    Returns number of tokens that will be penalized (destroyed)
    */
    function _calculatePenalty(
        uint256 collectPayoutAmount,
        uint256 amount,
        AmountType amountType
    ) private pure returns (uint256) {
        // If payout amount is greater than or equal to what user wants to collect then return early with 0 penalty
        if (collectPayoutAmount >= amount) {
            return 0;
        }

        // Calculate the remaining number of tokens to force payout
        uint256 penalizedAmountToCollect = amount - collectPayoutAmount;

        // If to wallet type, we double this amount (as it will later be penalized by 50%)
        // to ensure user receives this amount into their wallet
        if (amountType == AmountType.TO_WALLET) {
            penalizedAmountToCollect *= 2;
        }

        return penalizedAmountToCollect;
    }

    function _updateProcessedTime() private {
        // solhint-disable-next-line not-rely-on-time
        _accounts[msg.sender].lastProcessedTime = block.timestamp;
    }

    function _isAccountInPayout() private view returns (bool) {
        return _getStatus() == AccountStatus.PAYOUT;
    }

    function _isAccountInStake() private view returns (bool) {
        return _getStatus() == AccountStatus.STAKE;
    }

    function _getStatus() private view returns (AccountStatus) {
        return _accounts[msg.sender].status;
    }

    function _getBalance() private view returns (uint256) {
        return _accounts[msg.sender].balance;
    }

    function _setStatus(AccountStatus status) private {
        _accounts[msg.sender].status = status;
    }

    function _setBalance(uint256 amount) private {
        _accounts[msg.sender].balance = amount;
    }

    /*** ***/
}
