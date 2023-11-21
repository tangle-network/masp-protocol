/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

import "./IBatchTree.sol";

abstract contract IMultiAssetVAnchorBatchTree {
	function getRegistry() external view virtual returns (address);

	function getRewardUnspentTree() external view virtual returns (address);

	function getRewardSpentTree() external view virtual returns (address);

	function executeWrapping(address _fromToken, address _toToken, uint256 amount) external virtual;
}
