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

    // write functions
    function deposit(address _token, uint256 _amount) external returns (uint256 shares);
    function withdraw(address _token, uint256 _shares) external returns (uint256 amount);
    function swap(address _from, address _to, uint256 _amountIn) external returns (uint256 amountOut);
    
    // view functions
    function totalPoolValue() external view returns (uint256);
    function whitelistedTokens() external view returns (address[] memory whitelisted);
    function tokenTargetAllocation(address _token) external view returns (uint256);
    function getFeeConfig() external view returns (uint256 feeCap_, uint256 protocolFee_, address treasury_);
    function treasury() external view returns (address);
    function feeCap() external view returns (uint256);
    function protocolFee() external view returns (uint256);
}