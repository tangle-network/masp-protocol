# LST OMNIPOOL
* [Overview](#overview)
    - [deposit](#deposit)
    - [withdraw](#withdraw)
    - [swap](#swap)
* [Configuration](#configuration)
    - [fee config](#feeconfig)
    - [allocation target](#allocationtarget)
    - [whitelist](#whitelist)
* [Oracle](#oracle)
    - [prices](#prices)
    - [deposit amount](#depositvalue)
* [Fees](#fees)

## Overview
OmniPool contract is multi-asset pool, which allows user swap LSTs, deposit LSTs and earn interest from providing liquidity to the pool.

### deposit
OmniPool conract allows LST holders to deposit their token and getting shares in return by calling ```deposit``` function. Shares will be minted in protortion of their underlying ETH value to token underlying value. Share underlying value is calculated from total supply of shares and combined underlying ETH value of LST tokens in the pool.

### withdraw
Share holders can withdraw their deposits by burning shares with ```withdraw``` and selecting an output token of choice. Contract has anti-abuse mechanic for withdrawals for cases, when users attempt to swap their LST with two transaction with ```deposit``` and ```withdraw``` function calls, avoiding paying fees. Contract keeps track on what tokens were deposited by user, so that when user attempt to withdraw 100 shares from their combined __token A__ and  __token B__ deposits into output __token A__, the __A__ deposit will not be taxed, but deposit __B__ will be.

### swap
LST holders can swap their token for other LSTs in the pool. Both incoming and outgoing tokens are taxed with __input__ and __output__ [fees](#fees).

## Configuration
Configuration is an abstract part of OmniPool contract. IT contains set of access-restricted functions for setting protocol addresses like [Oracle](#oracle) and treasury, [fee configuration](#feeconfig), managing LSTs [whitelist](#whitelist) and setting [target allocation](#allocationtarget) for specific LSTs.

### FeeConfig
Fee configuration consists of multiple parts:
1. Treasury address - address of the recipient of protocol fees. 
2. Fee Cap - fee cap is the upper boundary for the fee percentage. Fees are calculated dynamically and the cap allows admin to control the heat of fee calculation output.
3. Protocol fee - amount of fee percentage that should be sent to the treasury. LSTs can be added and removed from the __whitelist__ by an admin.

### AllocationTarget
Admin of the pool can configure target allocation for each whitelisted LST, based on which pool will calculate fees for swaps.

### Whitelist
Whitelist is a list of LSTs, which are allowed to be deposited, withdrawn and swapped on this contract.

## Oracle
Oracle is a standalone contract, which contains logic for getching price and deposit values of whitelisted LSTs.
> [!WARNING]
> The oracle design is still in draft

The design caused by disadvantage of custom LST interfaces and variety of their implementations. There is no standard function signature to retrieve prices (or underlying token ratio to balance), hence oracle needs to support every possible implementation of  whitelisted LSTs.

### Prices
As example we can use the difference between __RocketETH__ and __LidoETH__. __LidoETH__ ```balanceOf``` dynamically calculates balance of certain address, based on the amount of underlying shares and their current relation to the locked ETH. While __RocketETH__ ```balanceOf``` returns static token amount and their relation to ETH is calculated with a separate function ```getExchangeRate```.

### DepositValue
Using the same example from previous topic we can conclude, that some LST implementations ```balanceOf``` functions are returning dynamic values, which are based on underlying shares. And there is no strict standard for retrieveng such shares. E.g. for fetching shares dor a deposit from __LidoETH__ we need to wrap ```getSharesByPooledEth``` function call on Oracle contract.

So if  governance decides to add __RocketETH__ to the pool, Oracle contract should be redeployed with new logic and oracle address must be changed on the OmniPool contract.

## Fees
OmniPool has two types of fees:
1. Protocol Fee - protocol fees are charged on each swap, or each unsustained withdrawal, when user deposit cannot cover their shares withdrawal. Portion on LSTs involved in swaps are sent to treasury address. This allows the protocol to earn a steady amount of income from swapping fees and that we build a foundation of the native stake token as a reserve for any future catastrophic events.
2. LP fee - the rest of swap fees are distributed evenly amoung share holders. These fees are not transferred anywhere, they are just left in the pool, which bumps underlying ETH value of the share.

Fees are calculated dynamically from relation of Pool's deposit value to target allocation. However fees cannot exceed the Fee cap, which is a defence mechanism, which prevents taxing user's too much.