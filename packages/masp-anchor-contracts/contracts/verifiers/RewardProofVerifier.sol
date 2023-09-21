/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

import "@webb-tools/protocol-solidity/utils/ProofUtils.sol";
import "../interfaces/IRewardVerifier.sol";

contract RewardProofVerifier is IRewardVerifier, ProofUtils {
	IRewardVerifier2_30 public v2_30;
	IRewardVerifier8_30 public v8_30;

	constructor(IRewardVerifier2_30 _verifier2_30, IRewardVerifier8_30 _verifier8_30) {
		v2_30 = _verifier2_30;
		v8_30 = _verifier8_30;
	}

	function verifyProof(
		bytes memory _proof,
		bytes memory input,
		uint8 maxEdges
	) external view override returns (bool r) {
		uint256[8] memory p = abi.decode(_proof, (uint256[8]));
		(uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) = unpackProof(p);
		if (maxEdges == 1) {
			uint256[18] memory _inputs = abi.decode(input, (uint256[18]));
			return v2_30.verifyProof(a, b, c, _inputs);
		} else if (maxEdges == 7) {
			uint256[30] memory _inputs = abi.decode(input, (uint256[30]));
			return v8_30.verifyProof(a, b, c, _inputs);
		} else {
			return false;
		}
	}
}
