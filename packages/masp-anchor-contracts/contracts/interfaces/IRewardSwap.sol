/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

interface IRewardSwap {
	function swap(address recipient, uint256 amount) external returns (uint256);

	function setPoolWeight(uint256 newWeight) external;
}
