/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "../interfaces/IRewardSwap.sol";

contract RewardSwap is IRewardSwap, ReentrancyGuard {
	using SafeERC20 for IERC20;

	uint256 public constant DURATION = 365 days;

	address public immutable governance;
	IERC20 public immutable tangle;
	address public manager;
	uint256 public immutable startTimestamp;
	uint256 public immutable initialLiquidity;
	uint256 public immutable liquidity;
	uint256 public tokensSold;
	uint256 public poolWeight;

	event RewardSwapped(address indexed recipient, uint256 AP, uint256 TNT);
	event PoolWeightUpdated(uint256 newWeight);

	modifier onlyGovernance() {
		require(msg.sender == governance, "Only governance can perform this action");
		_;
	}

	modifier onlyManager() {
		require(msg.sender == address(manager), "Only Miner contract can call");
		_;
	}

	constructor(
		address _governance,
		address _tangle,
		uint256 _miningCap,
		uint256 _initialLiquidity,
		uint256 _poolWeight
	) {
		require(
			_initialLiquidity <= _miningCap,
			"Initial liquidity should be lower than mining cap"
		);
		governance = _governance;
		tangle = IERC20(_tangle);
		manager = address(0);
		initialLiquidity = _initialLiquidity;
		liquidity = _miningCap - _initialLiquidity;
		poolWeight = _poolWeight;
		startTimestamp = getTimestamp();
	}

	function initialize(address _manager) external onlyGovernance nonReentrant {
		require(manager == address(0), "Already initialized");
		manager = _manager;
	}

	function swap(
		address _recipient,
		uint256 _amount
	) external onlyManager nonReentrant returns (uint256) {
		uint256 tokens = getExpectedReturn(_amount);
		tokensSold += tokens;
		require(tangle.transfer(_recipient, tokens), "transfer failed");
		emit RewardSwapped(_recipient, _amount, tokens);
		return tokens;
	}

	function getExpectedReturn(uint256 _amount) public view returns (uint256) {
		uint256 oldBalance = tntVirtualBalance();
		int128 pow = ABDKMath64x64.neg(ABDKMath64x64.divu(_amount, poolWeight));
		int128 exp = ABDKMath64x64.exp(pow);
		uint256 newBalance = ABDKMath64x64.mulu(exp, oldBalance);
		return (oldBalance - newBalance);
	}

	function tntVirtualBalance() public view returns (uint256) {
		uint256 passedTime = getTimestamp() - startTimestamp;
		if (passedTime < DURATION) {
			return initialLiquidity + ((liquidity * passedTime) / DURATION) - tokensSold;
		} else {
			return tangle.balanceOf(address(this));
		}
	}

	function setPoolWeight(uint256 _newWeight) external onlyManager nonReentrant {
		poolWeight = _newWeight;
		emit PoolWeightUpdated(_newWeight);
	}

	function getTimestamp() public view virtual returns (uint256) {
		return block.timestamp;
	}
}
