# Celery User Documentation

## Description

This documentation goes over the staking and payout functionality for the Celery Smart Contract. Celery also inherits all the same functionality from ERC-20.

## Public Functions

### Start Staking

Calling this function will switch your Account to staking and will begin to earn 100% APY on your existing Account Balance. You can stake for as long or as short as you want. See [Staking](#Staking) for the exact interest formula.

```
Parameters: none
Returns: none
Handled errors: If account is already staking
```

### Increase Balance And Stake

Calling this function will transfer tokens from your wallet into your Account Balance, and will switch your Account to  staking if its not already. You will begin to earn 100% APY interest on your entire Account Balance right away.

```
Parameters: amount (uint256)
Returns: none
Handled errors: If "amount" parameter is 0
```

### Start Payout

Calling this function will switch your Account to payout. Your Account Balance will slowly become available to collect, and will be fully available to collect after one year.

### Collect Payout

Calling this function will switch your Account to payout if its not already. Any available tokens in your Account Balance will be transfered back to your wallet. The amount of tokens that are considered available depends on how much time your Account has been in payout mode and the last time you collected payout. 

Here is an example. If you have 1,200 tokens in your Account Balance and you call Collect Payout once a month, or more specifically 1/12 of a year then 100 tokens will be transferred to your wallet each time for 12 months until your Account Balance reaches 0. It is important to rememeber that while your Account is in payout mode you do not earn any interest on your Account Balance.

```
Parameters: none
Returns: none
Handled errors: If the collected payout would be 0
```

### Force Payout

Use this function wisely.

In a situation where you do not want to wait for your Account Balance to become available, you can use force payout to collect unavailable tokens in your Account Balance. There is a 50% penalty for all the unavailable tokens you force collect.

When you use force payout you specify the number of tokens you wish to collect. Force payout will automatically collect all available tokens first before collecting unavailable ones. Only the unavailable tokens are penalized at 50%.

Here is an example. If your Account Balance has 1,000 tokens and your account has been in payout mode for 6 months or more specifically 1/2 year without collecting anything. Then 500 tokens will be available to collect, and 500 tokens will be unavailable to collect. If you force payout 1,000 tokens which is your entire Account balance then then force payout will first collect your 500 available tokens with no penalty and then collect the 500 unavailable tokens and apply a 50% penalty to them. You will then be transferred a total of 750 tokens back to your wallet.

```
Parameters: amount (uint256)
Returns: none
Handled errors: If "amount" parameter is 0 or if the force amount is greater than your account balance in the contract
```

### Get Account Balance

Retrieves the number of tokens in your account balance for the specified wallet address.

```
Parameters: address (Address)
Returns: amount (uint256)
```

### Get Last Processed Time

Retrieves the last time the account has been processed for the specified wallet address. Depending on if your account is in staking mode or payout mode. This is used interenally for both calculating how much interest has been earned and to calculate the number of tokens that are available to collect.

```
Parameters: address (Address)
Returns: epoch time in seconds (uint256)
```

### Get Last Staking Balance

Retrieves what the last staking Account Balance was before payout mode started for the specified wallet address. This is used internally for calculations to determine the number of tokens that are available to collect.

```
Parameters: address (Address)
Returns: amount (uint256)
```

### Get Status

Retrieves what the current Account status is for the specified wallet address. Returns back staking mode or payout mode. Default value is payout mode.

0 = Payout, 1 = Staking

```
Parameters: address (Address)
Returns: status (uint8)
```

## Math

### Staking

When staking you are earning continous compounding interest which equates to 100% APY or in laymen terms your Account balance will double in size every year when your Account is staking. The following is the exact formula used for calculating interest earned.

```
P * e^(r * t) = P(t)

P = Princpal Sum = Account Balance
P(t) = Value at time t
t = length of time the interest is applied for
r = APR = LN(2) = 0.69314...%
e = Euler's Number = 2.718...
APY = 100%
```

Here is an example. If your Account Balance has 1,000 tokens and you stake for 4 years then your Account Balance will have grown to 16,000.

```
1,000 * e^(LN(2) * 4) = 16,000
```

### Payout

When in payout mode your Account Balance slowly becomes available for you to collect. Your Account Balance will be fully available to collect after your account has been in payout mode for one year. You can collect payouts as often or as little as you want. Here are some examples.

If you have 1,200 tokens in your Account Balance and collect payout once per month. You will collect 100 tokens each time.

If you have 365 tokens in your Account Balance and collect payout once per day. You will collect 1 token each time.

You can switch your Account back and forth between Staking and Payout. It is important to know that when you switch your account back to staking any available tokens in your Account Balance will automatically be collected and transferred back to your wallet.

