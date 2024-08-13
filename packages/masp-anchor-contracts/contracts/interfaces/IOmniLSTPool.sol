// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IOmniLSTPool {
	// Events
	event Deposit(address indexed user, address token, uint256 amount, uint256 mintedShares);
	event Withdraw(address indexed user, address token, uint256 amount, uint256 burnedShares);
	event Swap(
		address indexed user,
		address fromToken,
		address toToken,
		uint256 amountIn,
		uint256 amountOut
	);
	event ParametersSet(address indexed setter, bytes32 paramName, bytes32 paramValue);

	// Structs
	struct TokenInfo {
		bool isWhitelisted;
		uint256 balance;
		uint256 targetAllocation;
		uint256 minAllocation;
		uint256 swapFee;
	}

	// Main functions
	function deposit(address token, uint256 amount) external returns (uint256 shares);

	function withdraw(address token, uint256 shares) external returns (uint256 amount);

	function swap(
		address fromToken,
		address toToken,
		uint256 amountIn
	) external returns (uint256 amountOut);

	// Admin functions
	function setParameters(bytes32 paramName, bytes32 paramValue) external;

	function whitelistToken(address token) external;

	function setTargetAllocation(address token, uint256 targetAllocation) external;

	function setMinAllocation(address token, uint256 minAllocation) external;

	// View functions
	function getTokenInfo(address token) external view returns (TokenInfo memory);

	function getPoolShare(address token) external view returns (uint256);

	function getTotalPoolValue() external view returns (uint256);

	function getOraclePrice(address token) external view returns (uint256);
}
