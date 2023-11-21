/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

/**
    @title IRewardVerifier interface
    @notice A generic interface for verifying zero-knowledge proofs for 
	anonymity mining reward proofs of different anchor size and tree depths.

	Returns  bool true if proof is valid.
 */
interface IRewardVerifier {
	function verifyProof(
		bytes memory _proof,
		bytes memory input,
		uint8 maxEdges
	) external view returns (bool r);
}

/**
    @title IRewardVerifier2_30 interface with #edges=2 #depth=30
 */
interface IRewardVerifier2_30 {
	// match the signature with corresponding verifier located in
	// <../verifiers/reward_*/VerifierReward_*.sol>
	function verifyProof(
		uint[2] memory a,
		uint[2][2] memory b,
		uint[2] memory c,
		uint256[27] memory input
	) external view returns (bool r);
}

/**
    @title IRewardVerifier8_30 interface with #edges=8 #depth=30
 */
interface IRewardVerifier8_30 {
	// match the signature with corresponding verifier located in
	// <../verifiers/reward_*/VerifierReward_*.sol>
	function verifyProof(
		uint[2] memory a,
		uint[2][2] memory b,
		uint[2] memory c,
		uint256[39] memory input
	) external view returns (bool r);
}
