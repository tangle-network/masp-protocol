// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOmniPool {
    // Errors
	error TokenIsNotWhitelisted(address);
    error NotEnoughTokensToWithdraw();
    error ArgumentsLengthMismatch();
    error WithdrawAmountIsZero();
	error DepositAmountIsZero();
    error SwapAmountIsZero();

    // Events
	event Deposit(
        address indexed user,
        address token,
        uint256 amount,
        uint256 mintedShares
    );
	event Withdraw(
        address indexed user,
        address token,
        uint256 amount,
        uint256 burnedShares
    );
	event Swap(
		address indexed user,
		address fromToken,
		address toToken,
		uint256 amountIn,
		uint256 amountOut
	);
    event OracleChanged(
        address oldOracle,
        address newOracle
    );

    // non-restricted functions
    function deposit(address _token, uint256 _amount) external returns (uint256 shares);
    function withdraw(address _token, uint256 _shares) external returns (uint256 amount);
    function swap(address _from, address _to, uint256 _amountIn) external returns (uint256 amountOut);
    
    // view functions
    function getWhitelistedTokens() external view returns (address[] memory whitelisted);
    function totalPoolValue() public view returns (uint256 value);

    // admin functions
}