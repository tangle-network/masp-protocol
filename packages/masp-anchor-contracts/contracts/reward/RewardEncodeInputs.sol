// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

uint8 constant WHITELISTED_ASSET_ID_LIST_SIZE = 10;

struct RewardExtData {
	uint256 fee;
	address recipient;
	address relayer;
}

struct RewardPublicInputs {
	uint256 anonymityRewardPoints;
	uint256 rewardNullifier;
	uint256 extDataHash;
	bytes whitelistedAssetIDs;
	bytes rates;
	bytes spentRoots;
	bytes unspentRoots;
}

/**
RewardEncodeInputs library is used to encode the public inputs for the Reward circuit
 */

library RewardEncodeInputs {
	/**
        @notice Encodes the public inputs into ZKP verifier suitable format
        @param _args The proof arguments
        @param _maxEdges The maximum # of edges supported by the connected VAnchor
        @return (bytes, uint32[10], uint256[], uint256[]) The public inputs and roots array separated
     */
	function _encodeInputs(
		RewardPublicInputs memory _args,
		uint8 _maxEdges
	)
		public
		pure
		returns (
			bytes memory,
			uint32[WHITELISTED_ASSET_ID_LIST_SIZE] memory,
			uint32[WHITELISTED_ASSET_ID_LIST_SIZE] memory,
			uint256[] memory,
			uint256[] memory
		)
	{
		uint32[10] memory whitelistedAssetIDs = abi.decode(_args.whitelistedAssetIDs, (uint32[10]));
		uint32[10] memory rates = abi.decode(_args.rates, (uint32[10]));
		uint256[] memory spentRootsResult = new uint256[](_maxEdges);
		uint256[] memory unspentRootsResult = new uint256[](_maxEdges);
		bytes memory encodedInput;
		uint8 i = 0;
		if (_maxEdges == 2) {
			uint256[18] memory inputs;
			uint256[2] memory spentRoots = abi.decode(_args.spentRoots, (uint256[2]));
			uint256[2] memory unspentRoots = abi.decode(_args.unspentRoots, (uint256[2]));

			// assign spent roots
			spentRootsResult[0] = spentRoots[0];
			spentRootsResult[1] = spentRoots[1];

			// assign unspent roots
			unspentRootsResult[0] = unspentRoots[0];
			unspentRootsResult[1] = unspentRoots[1];

			inputs[i++] = uint256(_args.anonymityRewardPoints);
			inputs[i++] = uint256(_args.rewardNullifier);
			inputs[i++] = uint256(_args.extDataHash);
			inputs[i++] = uint256(whitelistedAssetIDs[0]);
			inputs[i++] = uint256(whitelistedAssetIDs[1]);
			inputs[i++] = uint256(whitelistedAssetIDs[2]);
			inputs[i++] = uint256(whitelistedAssetIDs[3]);
			inputs[i++] = uint256(whitelistedAssetIDs[4]);
			inputs[i++] = uint256(whitelistedAssetIDs[5]);
			inputs[i++] = uint256(whitelistedAssetIDs[6]);
			inputs[i++] = uint256(whitelistedAssetIDs[7]);
			inputs[i++] = uint256(whitelistedAssetIDs[8]);
			inputs[i++] = uint256(whitelistedAssetIDs[9]);
			inputs[i++] = uint256(rates[0]);
			inputs[i++] = uint256(rates[1]);
			inputs[i++] = uint256(rates[2]);
			inputs[i++] = uint256(rates[3]);
			inputs[i++] = uint256(rates[4]);
			inputs[i++] = uint256(rates[5]);
			inputs[i++] = uint256(rates[6]);
			inputs[i++] = uint256(rates[7]);
			inputs[i++] = uint256(rates[8]);
			inputs[i++] = uint256(rates[9]);
			inputs[i++] = uint256(spentRoots[0]);
			inputs[i++] = uint256(spentRoots[1]);
			inputs[i++] = uint256(unspentRoots[0]);
			inputs[i++] = uint256(unspentRoots[1]);
			// Encode the inputs into a single bytes array
			encodedInput = abi.encodePacked(inputs);
		} else if (_maxEdges == 8) {
			uint256[30] memory inputs;
			uint256[8] memory spentRoots = abi.decode(_args.spentRoots, (uint256[8]));
			uint256[8] memory unspentRoots = abi.decode(_args.unspentRoots, (uint256[8]));

			// assign spent roots
			spentRootsResult[0] = spentRoots[0];
			spentRootsResult[1] = spentRoots[1];
			spentRootsResult[2] = spentRoots[2];
			spentRootsResult[3] = spentRoots[3];
			spentRootsResult[4] = spentRoots[4];
			spentRootsResult[5] = spentRoots[5];
			spentRootsResult[6] = spentRoots[6];
			spentRootsResult[7] = spentRoots[7];

			// assign unspent roots
			unspentRootsResult[0] = unspentRoots[0];
			unspentRootsResult[1] = unspentRoots[1];
			unspentRootsResult[2] = unspentRoots[2];
			unspentRootsResult[3] = unspentRoots[3];
			unspentRootsResult[4] = unspentRoots[4];
			unspentRootsResult[5] = unspentRoots[5];
			unspentRootsResult[6] = unspentRoots[6];
			unspentRootsResult[7] = unspentRoots[7];

			// assign inputs
			inputs[i++] = uint256(_args.anonymityRewardPoints);
			inputs[i++] = uint256(_args.rewardNullifier);
			inputs[i++] = uint256(_args.extDataHash);
			inputs[i++] = uint256(whitelistedAssetIDs[0]);
			inputs[i++] = uint256(whitelistedAssetIDs[1]);
			inputs[i++] = uint256(whitelistedAssetIDs[2]);
			inputs[i++] = uint256(whitelistedAssetIDs[3]);
			inputs[i++] = uint256(whitelistedAssetIDs[4]);
			inputs[i++] = uint256(whitelistedAssetIDs[5]);
			inputs[i++] = uint256(whitelistedAssetIDs[6]);
			inputs[i++] = uint256(whitelistedAssetIDs[7]);
			inputs[i++] = uint256(whitelistedAssetIDs[8]);
			inputs[i++] = uint256(whitelistedAssetIDs[9]);
			inputs[i++] = uint256(rates[0]);
			inputs[i++] = uint256(rates[1]);
			inputs[i++] = uint256(rates[2]);
			inputs[i++] = uint256(rates[3]);
			inputs[i++] = uint256(rates[4]);
			inputs[i++] = uint256(rates[5]);
			inputs[i++] = uint256(rates[6]);
			inputs[i++] = uint256(rates[7]);
			inputs[i++] = uint256(rates[8]);
			inputs[i++] = uint256(rates[9]);
			inputs[i++] = uint256(spentRoots[0]);
			inputs[i++] = uint256(spentRoots[1]);
			inputs[i++] = uint256(spentRoots[2]);
			inputs[i++] = uint256(spentRoots[3]);
			inputs[i++] = uint256(spentRoots[4]);
			inputs[i++] = uint256(spentRoots[5]);
			inputs[i++] = uint256(spentRoots[6]);
			inputs[i++] = uint256(spentRoots[7]);
			inputs[i++] = uint256(unspentRoots[0]);
			inputs[i++] = uint256(unspentRoots[1]);
			inputs[i++] = uint256(unspentRoots[2]);
			inputs[i++] = uint256(unspentRoots[3]);
			inputs[i++] = uint256(unspentRoots[4]);
			inputs[i++] = uint256(unspentRoots[5]);
			inputs[i++] = uint256(unspentRoots[6]);
			inputs[i++] = uint256(unspentRoots[7]);
			// Encode the inputs into a single bytes array
			encodedInput = abi.encodePacked(inputs);
		} else {
			require(false, "Invalid edges");
		}

		return (encodedInput, whitelistedAssetIDs, rates, spentRootsResult, unspentRootsResult);
	}
}
