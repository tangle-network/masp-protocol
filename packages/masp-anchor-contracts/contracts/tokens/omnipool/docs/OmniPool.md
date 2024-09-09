# LST OMNIPOOL
* [Overview](##overview)
* [Configuration](###configuration)
* [Oracle](###oracle)
* [Fees](###fees)

## Overview
OmniPool conract allows LST holders to deposit their token and getting shares in return by calling ```deposit``` function. Shares will be minted in protortion of their underlying ETH value to token underlying value. Share underlying value is calculated from total supply of shares and combined underlying ETH value of LST tokens in the pool.

Share holders can withdraw their deposits by burning shares with ```withdraw``` and selecting an output token of choice. Contract has anti-abuse mechanic for withdrawals for cases, when users attempt to swap their LST with two transaction with ```deposit``` and ```withdraw``` function calls, avoiding paying fees. Contract keeps track on what tokens were deposited by user, so that when user attempt to withdraw 100 shares from their combined __A__ and __B__ deposits into output token __A__, the __A__ deposit will not be taxed, but deposit __B__ will.

LST holders can swap their token for other LSTs in the pool. Both incoming and outgoing tokens are taxed with __input__ and __output__ fees. Fees are dynamically calculated from current token amount in the pool, allocation target (settable by the admin).

Shares are based on ERC20 standard. Can be minted, burned, transferred and approved.

### Configuration
Configuration is an abstract part of OmniPool contract. IT contains set of access-restricted functions for setting protocol addresses like Oracle and treasury, fee configuration, managing LSTs whitelist and setting target allocation for specific LSTs.

### Oracle

Oracle is a standalone contract, which contains logic for getching price and underlying values of whitelisted LSTs.

The design caused by disadvantage of custom LST interfaces and variety of their implementations. There is no standard function signature to retrieve prices (or underlying token ratio to balance), hence oracle needs to support every possible implementation of  whitelisted LSTs.

As example we can use the difference between __RocketETH__ and __LidoETH__. __LidoETH__ ```balanceOf``` dynamically calculates balance of certain address, based on the amount of underlying shares and their current relation to the locked ETH. While __RocketETH__ ```balanceOf``` returns static token amount and their relation to ETH is calculated with a separate function ```getExchangeRate```.

> [!WARNING]
> The oracle design is still in draft

So if  governance decides to add __RocketETH__ to the pool, Oracle contract should be redeployed with new logic and oracle address must be changed on the OmniPool contract.