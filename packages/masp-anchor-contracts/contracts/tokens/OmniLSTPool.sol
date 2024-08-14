// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IOmniLSTPool.sol";

/// @title OmniLSTPool
/// @notice A DeFi protocol for creating an omni pool for liquid staked tokens (LSTs)
/// @dev This contract implements the IOmniLSTPool interface and is itself an ERC20 token
contract OmniLSTPool is IOmniLSTPool, ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Mapping of token address to its information
    mapping(address => TokenInfo) public tokenInfo;

    /// @notice Precision factor for calculations
    uint256 public constant PRECISION = 1e18;

    /// @notice Constructs the OmniLSTPool contract
    /// @param name The name of the OmniLST token
    /// @param symbol The symbol of the OmniLST token
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable() {}

    /// @notice Ensures that the token is whitelisted
    /// @param token The address of the token to check
    modifier onlyWhitelistedToken(address token) {
        require(tokenInfo[token].isWhitelisted, "Token not whitelisted");
        _;
    }

    /// @notice Deposits tokens into the pool and mints OmniLST tokens
    /// @param token The address of the token to deposit
    /// @param amount The amount of tokens to deposit
    /// @return shares The number of OmniLST tokens minted for the deposit
    function deposit(address token, uint256 amount) external override nonReentrant onlyWhitelistedToken(token) returns (uint256 shares) {
        require(amount > 0, "Deposit amount must be greater than 0");

        uint256 poolValueBefore = getTotalPoolValue();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        tokenInfo[token].balance += amount;

        shares = totalSupply() == 0 ? amount : (amount * totalSupply()) / poolValueBefore;
        require(shares > 0, "Shares minted must be greater than 0");

        _mint(msg.sender, shares);

        emit Deposit(msg.sender, token, amount, shares);
        return shares;
    }

    /// @notice Burns OmniLST tokens and withdraws underlying tokens
    /// @param token The address of the token to withdraw
    /// @param shares The number of OmniLST tokens to burn
    /// @return amount The amount of tokens withdrawn
    function withdraw(address token, uint256 shares) external override nonReentrant onlyWhitelistedToken(token) returns (uint256 amount) {
        require(shares > 0 && shares <= balanceOf(msg.sender), "Invalid shares amount");

        uint256 poolValue = getTotalPoolValue();
        amount = (shares * poolValue) / totalSupply();
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(amount <= tokenInfo[token].balance, "Insufficient pool balance");

        _burn(msg.sender, shares);
        tokenInfo[token].balance -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount, shares);
        return amount;
    }

    /// @notice Swaps one whitelisted token for another
    /// @param fromToken The address of the token to swap from
    /// @param toToken The address of the token to swap to
    /// @param amountIn The amount of fromToken to swap
    /// @return amountOut The amount of toToken received from the swap
    function swap(address fromToken, address toToken, uint256 amountIn) external override nonReentrant onlyWhitelistedToken(fromToken) onlyWhitelistedToken(toToken) returns (uint256 amountOut) {
        require(amountIn > 0, "Swap amount must be greater than 0");
        require(fromToken != toToken, "Cannot swap same token");

        uint256 fromTokenPrice = getOraclePrice(fromToken);
        uint256 toTokenPrice = getOraclePrice(toToken);

        uint256 valueIn = (amountIn * fromTokenPrice) / PRECISION;
        amountOut = (valueIn * PRECISION) / toTokenPrice;

        uint256 swapFee = (amountOut * tokenInfo[toToken].swapFee) / PRECISION;
        amountOut -= swapFee;

        require(amountOut > 0, "Insufficient output amount");
        require(amountOut <= tokenInfo[toToken].balance, "Insufficient pool balance");

        IERC20(fromToken).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(toToken).safeTransfer(msg.sender, amountOut);

        tokenInfo[fromToken].balance += amountIn;
        tokenInfo[toToken].balance -= amountOut;

        _adjustSwapFees(fromToken, toToken);

        emit Swap(msg.sender, fromToken, toToken, amountIn, amountOut);
        return amountOut;
    }

    /// @notice Sets protocol parameters
    /// @param paramName The name of the parameter to set
    /// @param paramValue The value to set for the parameter
    function setParameters(bytes32 paramName, bytes32 paramValue) external override onlyOwner {
        // Implementation depends on specific parameters
        emit ParametersSet(msg.sender, paramName, paramValue);
    }

    /// @notice Whitelists a token for use in the pool
    /// @param token The address of the token to whitelist
    function whitelistToken(address token) external override onlyOwner {
        require(!tokenInfo[token].isWhitelisted, "Token already whitelisted");
        tokenInfo[token].isWhitelisted = true;
    }

    /// @notice Sets the target allocation for a token
    /// @param token The address of the token
    /// @param targetAllocation The target allocation to set
    function setTargetAllocation(address token, uint256 targetAllocation) external override onlyOwner onlyWhitelistedToken(token) {
        require(targetAllocation <= PRECISION, "Invalid target allocation");
        tokenInfo[token].targetAllocation = targetAllocation;
    }

    /// @notice Sets the minimum allocation for a token
    /// @param token The address of the token
    /// @param minAllocation The minimum allocation to set
    function setMinAllocation(address token, uint256 minAllocation) external override onlyOwner onlyWhitelistedToken(token) {
        require(minAllocation <= tokenInfo[token].targetAllocation, "Min allocation cannot exceed target");
        tokenInfo[token].minAllocation = minAllocation;
    }

    /// @notice Retrieves information about a specific token
    /// @param token The address of the token
    /// @return TokenInfo struct containing token information
    function getTokenInfo(address token) external view override returns (TokenInfo memory) {
        return tokenInfo[token];
    }

    /// @notice Calculates the pool share of a specific token
    /// @param token The address of the token
    /// @return The pool share of the token (in PRECISION units)
    function getPoolShare(address token) external view override returns (uint256) {
        uint256 poolValue = getTotalPoolValue();
        if (poolValue == 0) return 0;
        return (tokenInfo[token].balance * PRECISION) / poolValue;
    }

    /// @notice Calculates the total value of the pool
    /// @return totalValue The total value of all tokens in the pool
    function getTotalPoolValue() public view override returns (uint256 totalValue) {
        address[] memory whitelistedTokens = _getWhitelistedTokens();
        for (uint256 i = 0; i < whitelistedTokens.length; i++) {
            address token = whitelistedTokens[i];
            totalValue += (tokenInfo[token].balance * getOraclePrice(token)) / PRECISION;
        }
        return totalValue;
    }

    /// @notice Retrieves the oracle price for a token
    /// @param token The address of the token
    /// @return The price of the token (in PRECISION units)
    function getOraclePrice(address token) public view override returns (uint256) {
        // Implement oracle price fetching logic here
        // This is a placeholder and should be replaced with actual oracle implementation
        return 1e18;
    }

    /// @notice Retrieves the amount of underlying staking tokens in a specific LST token
    /// @param token The address of the LST token
    /// @return The amount of underlying staking tokens
    function getUnderlyingStakingTokens(address token) external view returns (uint256) {
        // Implement logic to fetch the amount of underlying staking tokens
        // This is a placeholder and should be replaced with actual implementation
        // For example, if the LST token has a method to get the underlying amount, it can be called here
        // return ILSTToken(token).getUnderlyingStakingTokens();
        return tokenInfo[token].balance; // Placeholder: assuming balance represents underlying staking tokens
    }

    /// @notice Adjusts swap fees based on current pool shares and target allocations
    /// @param fromToken The address of the token being swapped from
    /// @param toToken The address of the token being swapped to
    function _adjustSwapFees(address fromToken, address toToken) internal {
        uint256 fromTokenShare = this.getPoolShare(fromToken);
        uint256 toTokenShare = this.getPoolShare(toToken);

        if (fromTokenShare < tokenInfo[fromToken].targetAllocation) {
            tokenInfo[fromToken].swapFee = tokenInfo[fromToken].swapFee * 99 / 100; // Decrease by 1%
        } else {
            tokenInfo[fromToken].swapFee = tokenInfo[fromToken].swapFee * 101 / 100; // Increase by 1%
        }

        if (toTokenShare > tokenInfo[toToken].targetAllocation) {
            tokenInfo[toToken].swapFee = tokenInfo[toToken].swapFee * 99 / 100; // Decrease by 1%
        } else {
            tokenInfo[toToken].swapFee = tokenInfo[toToken].swapFee * 101 / 100; // Increase by 1%
        }
    }

    /// @notice Retrieves the list of whitelisted tokens
    /// @return An array of addresses of whitelisted tokens
    function _getWhitelistedTokens() internal view returns (address[] memory) {
        // Implement logic to return all whitelisted tokens
        // This is a placeholder and should be replaced with actual implementation
        address[] memory tokens;
        return tokens;
    }
}