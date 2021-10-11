# Celery User Documentation

## Description

This documentation goes over the staking and payout functionality for the Celery Smart Contract. Celery also inherits all the same functionality from ERC-20.


## Public State Changing Functions

### Start Staking

Calling this function will switch your Account to staking and will begin to earn 100% APY on your existing Account Balance. You can stake for as long or as short as you want. See [Staking](#Staking) for the exact interest formula.

```
Function Name: startStake
Parameters: none
Returns: none
Contract handled errors: If account is already staking
```

### Increase Balance And Stake

Calling this function will transfer tokens from your wallet into your Account Balance, and will switch your Account to staking if its not already. You will begin to earn 100% APY interest on your entire Account Balance right away.

```
Function Name: increaseBalanceAndStake
Parameters: amount (uint256)
Returns: none
Contract handled errors: If amount parameter is 0
```

### Start Payout

Calling this function will switch your Account to payout. Your Account Balance will slowly become available to collect, and will be fully available to collect after one year.

```
Function Name: startPayout
Parameters: none
Returns: none
Contract handled errors: If account is already in payout
```

### Collect Payout

Your account must be in payout before collecting. Calling this function will transfer all available tokens in your Account Balance back into your wallet. The amount of tokens that are considered available depends on how much time your Account has been in payout mode and the last time you collected payout. 

Here is an example. If you have 1,200 tokens in your Account Balance and you call Collect Payout once a month, or more specifically 1/12 of a year then 100 tokens will be transferred to your wallet each time for 12 months until your Account Balance reaches 0. It is important to rememeber that while your Account is in payout mode you do not earn any interest on your Account Balance.

```
Function Name: collectPayout
Parameters: none
Returns: none
Contract handled errors: If the collected payout would be 0 or if account is staking
```

### Force Payout

Use this function wisely. Your account will automatically switch to payout if it is staking when exectuted.

In a situation where you do not want to wait for tokens in your Account Balance to become available, you can use force payout to collect unavailable tokens in your Account Balance. There is a 50% penalty for all the unavailable tokens that are force collected FROM the account.

A parameter is required to determine how you want to handle the amount you specified. If FROM_ACCOUNT is used, then the amount you specifiy will be the amount collected FROM the account. If any portion of this amount is penalized, your wallet will receieve LESS than the amount you specified. If TO_WALLET is used, then the amount you specifiy will be the amount you recieve TO your wallet. If any portion of this amount is penalized, your account will have MORE than the amount you specified removed.

When you use force payout you specify the number of tokens you wish to collect. Force payout will automatically collect all available tokens first before collecting unavailable ones. Only the unavailable tokens are penalized at 50%. If the number of available tokens is greater than what you specified (FROM_ACCOUNT) or specified multiplied by 2 (TO_WALLET), then no unavailable tokens will be force collected and you will not be penalized.

Here is an example. If your Account Balance has 1,000 tokens and your account has been in payout mode for 6 months or more specifically 1/2 year without collecting anything. Then 500 tokens will be available to collect, and 500 tokens will be unavailable to collect. If you force payout 1,000 tokens which is your entire Account balance then the force payout will first collect your 500 available tokens with no penalty and then collect the 500 unavailable tokens and apply a 50% penalty to them. You will then be transferred a total of 750 tokens back to your wallet.

```
Function Name: forcePayout
Parameters: amount (uint256), amountType (uint8) [0 = TO_WALLET, 1 = FROM_ACCOUNT]
Returns: none
Contract handled errors: If "amount" parameter is 0 or if the force amount is greater than your account balance in the contract (FROM_ACCOUNT) or if the force amount multiplied by 2 is greater than your account balance (TO_WALLET)
```


## Public View Functions

### Get Account Balance

Retrieves the number of tokens in the account balance for the specified wallet address.

```
Function Name: getAccountBalance
Parameters: address (Address)
Returns: Account balance (uint256)
```

### Get Last Processed Time

Retrieves the last time the account has been processed for the specified wallet address. Depending on if the account is in staking mode or payout mode. This is used interenally for both calculating how much interest has been earned and to calculate the number of tokens that are available to collect.

```
Function Name: getLastProcessedTime
Parameters: address (Address)
Returns: Last processed time [epoch time in seconds] (uint256)
```

### Get Last Staking Balance

Retrieves what the last staking Account Balance was before payout mode started for the specified wallet address. This is used internally for calculations to determine the number of tokens that are available to collect.

```
Function Name: getLastStakingBalance
Parameters: address (Address)
Returns: Last staking balance (uint256)
```

### Get Status

Retrieves what the current Account status is for the specified wallet address. Returns back staking mode or payout mode. Default value is payout mode.

0 = Payout, 1 = Staking

```
Function Name: getStatus
Parameters: address (Address)
Returns: Status [0 = Payout, 1 = Staking] (uint8)
```

### Get End Interest Time

Retrieves the end time when interest stops. This is calculated upon contract creation and is due to the limit of the 256 bit numbers all contracts use. After this date, no more Celery can be created, which means staking stops

```
Function Name: getEndInterestTime
Parameters: address (Address)
Returns: End interest time [epoch time in seconds] (uint256)
```

### Get Circulating Supply

Retrieves the circulating token supply excluding all staking and payout tokens.

```
Function Name: getCirculatingSupply
Returns: Circulating token supply (uint256)
```

### Get Total Staking Supply

Calculates and retrieves the total token staking supply.

```
Function Name: getTotalStakingSupply
Returns: Staking token supply (uint256)
```

### Get Total Payout Supply

Retrieves the total payout supply

```
Function Name: getTotalPayoutSupply
Returns: Payout token supply (uint256)
```

### Get Fully Diluted Supply

Retrieves the fully dilulted token supply which includes all staking and payout tokens.

```
Function Name: getFullyDilutedSupply
Returns: Fully diluted token supply (uint256)
```

### Estimate Collect Payout

This allows you to perform an estimate on what would happen if you executed a Collect Payout at a certain point in time, assuming you stay in the payout status the entire time. Passing in a timestamp of a future date since you've started your payout will tell you how much you would received if the Collect Payout function was executed at that exact time. Running a collect/force payout or changing back into stake status after the estimate is run would require it to be run again, as it would be out of date.

```
Function Name: estimateCollect
Parameters: address (Address), timeStamp [epoch time in seconds] (uint256)
Returns: Estimated collect payout you would receive (uint256)
Contract handled errors: If the timestamp provided is earlier than when the payout started, or if account is staking
```

### Estimate Stake Balance

This allows you to perform an estimate on how much celery you would have at a certain point in time based on your current balance, assuming you stay in the stake status the entire time, perform no collections, and also do not deposit any more celery. If one of those things change after the estimate, it would need to be run again, as it would be out of date.

```
Function Name: estimateStakeBalance
Parameters: address (Address), timeStamp [epoch time in seconds] (uint256)
Returns: Estimated account balance with stake value (uint256)
Contract handled errors: If the timestamp provided is earlier than when the staking started, or if account is in payout
```

### Estimate Force Payout Penalty Fee

This allows you to perform an estimate on how much celery would be destroyed by the penalty applied to your unavailable balance upon a Force payout operation. Since a Collect payout occurs when a Force payout occurs, the penalty for a given amount decreases over time, as more of your balance becomes avaialble to you without penalty. This function assists by taking that into consideration, and will tell you how much your penalty would be for a specific amount if a Force payout was executed at a specific time. The more time that has past, the less the penalty. The penalty can also be 0 if the Collect payout covers the requested force payout balance.

```
Function Name: estimateForcePayoutPenaltyFee
Parameters: address (Address), amount (uint256), amountType (uint8) [0 = TO_WALLET, 1 = FROM_ACCOUNT], timeStamp [epoch time in seconds] (uint256)
Returns: Estimated Celery penalty that would be taken (uint256)
Contract handled errors: If the timestamp provided is earlier than when the staking or payout status started, amount is 0, or the penalty is higher than what your account balance could cover at the time.
```


## Math

### Staking

When staking you are earning continous compounding interest which equates to 100% APY or in laymen terms your Account balance will double in size for each year that your Account is staking. The following is the exact formula used for calculating interest earned.

```
P * e^(r * t) = P(t)

P = Princpal Sum = Account Balance
P(t) = Value at time t
t = length of time the interest is applied for
r = APR = LN(2) = 0.69314...%
e = Euler's Number = 2.718...
APY = 100%

P(t) = P * e^(LN(2) * t) = P * 2^t
```

Here is an example. If your Account Balance has 1,000 tokens and you stake for 4 years then your Account Balance will have grown to 16,000.

```
1,000 * 2^4 = 16,000
```

### Payout

When in payout mode your Account Balance slowly becomes available for you to collect. Your Account Balance will be fully available to collect after your account has been in payout mode for one year. You can collect payouts as often or as little as you want. Here are some examples.

If you have 1,200 tokens in your Account Balance and collect payout once per month. You will collect 100 tokens each time.

If you have 365 tokens in your Account Balance and collect payout once per day. You will collect 1 token each time.

You can switch your Account back and forth between Staking and Payout. It is important to know that when you switch your account back to staking any available tokens in your Account Balance will automatically be collected and transferred back to your wallet.

