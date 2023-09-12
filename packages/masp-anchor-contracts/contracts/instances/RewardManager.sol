/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

import "../interfaces/IRewardSwap.sol";
import "../interfaces/IRewardVerifier.sol";
import "../interfaces/IMASPProxy.sol";
import "../PublicInputs.sol";
import "../RewardEncodeInputs.sol";

contract RewardManager {
	IMASPProxy public immutable maspProxy;
	IRewardSwap public immutable rewardSwap;
	IRewardVerifier public immutable rewardVerifier;

	mapping(bytes32 => bool) public rewardNullifiers;
	uint256 public rate;

	uint8 public maxEdges;

	constructor(
		address _maspProxy,
		address _rewardSwap,
		address _rewardVerifier,
		uint256 _rate,
		uint8 _maxEdges
	) {
		maspProxy = IMASPProxy(_maspProxy);
		rewardSwap = IRewardSwap(_rewardSwap);
		rewardVerifier = IRewardVerifier(_rewardVerifier);
		rate = _rate;
		maxEdges = _maxEdges;
	}

	function reward(bytes memory _proof, RewardPublicInputs memory _publicInputs) public {
		(
			bytes memory encodedInputs,
			uint256[] memory spentRoots,
			uint256[] memory unspentRoots
		) = RewardEncodeInputs._encodeInputs(_publicInputs, maxEdges);

		// #TODO
		//maspProxy.validateRoots(spentRoots, unspentRoots);
		require(
			bytes32(_publicInputs.extDataHash) == keccak256(abi.encode(_publicInputs.extData)),
			"Incorrect external data hash"
		);
		require(_publicInputs.rate == rate && _publicInputs.rate > 0, "Invalid reward rate");
		require(
			!rewardNullifiers[bytes32(_publicInputs.rewardNullifier)],
			"Reward has been already spent"
		);

		// Verify the proof
		require(
			IRewardVerifier(rewardVerifier).verifyProof(_proof, encodedInputs, maxEdges),
			"Invalid reward proof"
		);

		// mark that reward has been awarded
		rewardNullifiers[bytes32(_publicInputs.rewardNullifier)] = true;

		// Transfer to the recipient
		uint256 rewardAmountMinusFee = _publicInputs.rewardAmount - _publicInputs.extData.fee;
		if (rewardAmountMinusFee > 0) {
			rewardSwap.swap(_publicInputs.extData.recipient, rewardAmountMinusFee);
		}
		// Transfer to the relayer
		if (_publicInputs.extData.fee > 0) {
			rewardSwap.swap(_publicInputs.extData.relayer, _publicInputs.extData.fee);
		}
	}
}
