/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@webb-tools/protocol-solidity/hashers/IHasher.sol";
import "../interfaces/IRewardSwap.sol";
import "../interfaces/IRewardVerifier.sol";
import "./RewardEncodeInputs.sol";

contract RewardManager is ReentrancyGuard {
	// this constant is taken from the Verifier.sol generated from circom library
	uint256 SNARK_SCALAR_FIELD_SIZE =
		21888242871839275222246405745257275088548364400416034343698204186575808495617;

	uint8 public constant ROOT_HISTORY_SIZE = 30;

	IRewardSwap public immutable rewardSwap;
	IRewardVerifier public immutable rewardVerifier;
	address public immutable governance;
	IHasher public hasher;

	mapping(bytes32 => bool) public rewardNullifiers;
	mapping(uint32 => bool) public validRewardAssetIDs;
	mapping(uint32 => bool) public rateExists;
	mapping(uint32 => uint32) public rates;

	struct Edge {
		uint256[ROOT_HISTORY_SIZE] spentRootList;
		uint256[ROOT_HISTORY_SIZE] unspentRootList;
		uint8 currentSpentRootListIndex;
		uint8 currentUnspentRootListIndex;
	}

	uint8 public maxEdges;
	mapping(uint256 => uint256) public chainIdToEdgeListIndex;
	mapping(uint256 => bool) public edgeExistsForChain;
	Edge[] public edgeList;

	event EdgeAdded(uint256 indexed chainId, uint256 indexed edgeIndex);
	event EdgeUpdated(uint256 indexed oldChainId, uint256 indexed newChainId);
	event RootAddedToSpentList(uint256 indexed chainId, uint256 root);
	event RootAddedToUnspentList(uint256 indexed chainId, uint256 root);

	event RatesUpdated(uint32[VALID_REWARD_ASSET_IDS_SIZE] newRates);
	// Event to log changes in validRewardAssetIDs.
	event RewardAssetsUpdate(uint32[] newValidRewardAssetIDs, uint32[] newRates);

	modifier onlyGovernance() {
		require(msg.sender == governance, "Only governance can perform this action");
		_;
	}

	constructor(
		address _rewardSwap,
		address _rewardVerifier,
		address _governance,
		address _hasher,
		uint8 _maxEdges,
		uint32[] memory _initialValidRewardAssetIDs,
		uint32[] memory _rates
	) {
		require(
			_initialValidRewardAssetIDs.length == _rates.length,
			"RewardManager: Invalid rates size"
		);
		rewardSwap = IRewardSwap(_rewardSwap);
		rewardVerifier = IRewardVerifier(_rewardVerifier);
		governance = _governance;
		hasher = IHasher(_hasher);
		maxEdges = _maxEdges;

		for (uint256 i = 0; i < _initialValidRewardAssetIDs.length; i++) {
			validRewardAssetIDs[_initialValidRewardAssetIDs[i]] = true;
			rates[_initialValidRewardAssetIDs[i]] = _rates[i];
			rateExists[_initialValidRewardAssetIDs[i]] = true;
		}
	}

	/// Claim a reward a spent UTXO using a zkSNARK proof
	/// @param _proof The SNARK proof
	/// @param _publicInputs The public inputs to the SNARK proof
	/// @param _extData The external data to the SNARK proof
	function reward(
		bytes memory _proof,
		RewardPublicInputs memory _publicInputs,
		RewardExtData memory _extData
	) public {
		// Destructure public input data
		(
			bytes memory encodedInput,
			uint32[VALID_REWARD_ASSET_IDS_SIZE] memory _validRewardAssetIDs,
			uint32[VALID_REWARD_ASSET_IDS_SIZE] memory _rates,
			uint256[] memory _spentRoots,
			uint256[] memory _unspentRoots
		) = RewardEncodeInputs._encodeInputs(_publicInputs, maxEdges);
		// Prevent double claim of rewards
		require(
			!rewardNullifiers[bytes32(_publicInputs.rewardNullifier)],
			"Reward has been already spent"
		);
		// Prevent modification of ExtData which includes addresses of recipient, relayer and fee
		require(
			_publicInputs.extDataHash ==
				uint256(_getExtDataHash(_extData)) % SNARK_SCALAR_FIELD_SIZE,
			"Incorrect external data hash"
		);
		require(_isValidRewardAssetIDs(_validRewardAssetIDs, _rates), "Invalid asset IDs");
		require(_isValidSpentRoots(_spentRoots), "Invalid spent roots");
		require(_isValidUnspentRoots(_unspentRoots), "Invalid spent roots");

		// verify the proof
		require(
			IRewardVerifier(rewardVerifier).verifyProof(_proof, encodedInput, maxEdges),
			"Invalid reward proof"
		);

		// mark that reward has been awarded
		rewardNullifiers[bytes32(_publicInputs.rewardNullifier)] = true;

		// Transfer to the recipient
		uint256 anonymityRewardPointsMinusFee = _publicInputs.anonymityRewardPoints - _extData.fee;
		if (anonymityRewardPointsMinusFee > 0) {
			rewardSwap.swap(_extData.recipient, anonymityRewardPointsMinusFee);
		}
		// Transfer to the relayer
		if (_extData.fee > 0) {
			rewardSwap.swap(_extData.relayer, _extData.fee);
		}
	}

	// Function to modify the validRewardAssetIDs.
	function setValidRewardAssetIDs(
		uint32[] memory _validRewardAssetIDs,
		uint32[] memory _rates
	) external onlyGovernance nonReentrant {
		require(_validRewardAssetIDs.length == _rates.length, "RewardManager: Invalid rates size");
		for (uint256 i = 0; i < _validRewardAssetIDs.length; i++) {
			validRewardAssetIDs[_validRewardAssetIDs[i]] = true;
			rates[_validRewardAssetIDs[i]] = _rates[i];
			rateExists[_validRewardAssetIDs[i]] = true;
		}
		emit RewardAssetsUpdate(_validRewardAssetIDs, _rates);
	}

	function setPoolWeight(uint256 _newWeight) external onlyGovernance nonReentrant {
		rewardSwap.setPoolWeight(_newWeight);
	}

	// Add a new edge.
	function addEdge(uint256 chainId) external onlyGovernance nonReentrant {
		require(!edgeExistsForChain[chainId], "Edge for this chainId already exist");
		require(edgeList.length < maxEdges, "Maximum number of edges reached");

		Edge memory newEdge;
		newEdge.currentSpentRootListIndex = 0;
		newEdge.currentUnspentRootListIndex = 0;
		edgeList.push(newEdge);

		uint256 edgeIndex = edgeList.length - 1;
		edgeExistsForChain[chainId] = true;
		chainIdToEdgeListIndex[chainId] = edgeIndex;
		emit EdgeAdded(chainId, edgeIndex);
	}

	// Add a root to the spent list of an existing edge.
	function addRootToSpentList(
		uint256 chainId,
		uint256 root
	) external onlyGovernance nonReentrant {
		require(edgeExistsForChain[chainId], "Edge for this chainId does not exist");
		Edge storage edge = edgeList[chainIdToEdgeListIndex[chainId]];
		edge.spentRootList[edge.currentSpentRootListIndex] = root;
		edge.currentSpentRootListIndex = (edge.currentSpentRootListIndex + 1) % ROOT_HISTORY_SIZE;
		emit RootAddedToSpentList(chainId, root);
	}

	// Add a root to the unspent list of an existing edge.
	function addRootToUnspentList(
		uint256 chainId,
		uint256 root
	) external onlyGovernance nonReentrant {
		require(edgeExistsForChain[chainId], "Edge for this chainId does not exist");
		Edge storage edge = edgeList[chainIdToEdgeListIndex[chainId]];
		edge.unspentRootList[edge.currentUnspentRootListIndex] = root;
		edge.currentUnspentRootListIndex =
			(edge.currentUnspentRootListIndex + 1) %
			ROOT_HISTORY_SIZE;
		emit RootAddedToUnspentList(chainId, root);
	}

	// Get the latest spent roots for all edges.
	function getLatestSpentRoots() external view returns (uint256[] memory) {
		uint256[] memory latestSpentRoots = new uint256[](maxEdges);

		for (uint256 i = 0; i < edgeList.length; i++) {
			uint256 edgeIndex = i;
			uint256 currentIndex = edgeList[edgeIndex].currentSpentRootListIndex;

			// If currentIndex is zero, it means the spentRootList is empty.
			// In such cases, we use 0 as a placeholder.
			if (currentIndex == 0) {
				latestSpentRoots[i] = 0;
			} else {
				// Otherwise, get the latest spent root from the spentRootList.
				latestSpentRoots[i] = edgeList[edgeIndex].spentRootList[
					(currentIndex - 1) % ROOT_HISTORY_SIZE
				];
			}
		}

		return latestSpentRoots;
	}

	// Get the latest unspent roots for all edges.
	function getLatestUnspentRoots() external view returns (uint256[] memory) {
		uint256[] memory latestUnspentRoots = new uint256[](maxEdges);

		for (uint256 i = 0; i < edgeList.length; i++) {
			uint256 edgeIndex = i;
			uint256 currentIndex = edgeList[edgeIndex].currentUnspentRootListIndex;

			// If currentIndex is zero, it means the unspentRootList is empty.
			// In such cases, we use 0 as a placeholder.
			if (currentIndex == 0) {
				latestUnspentRoots[i] = 0;
			} else {
				// Otherwise, get the latest unspent root from the unspentRootList.
				latestUnspentRoots[i] = edgeList[edgeIndex].unspentRootList[
					(currentIndex - 1) % ROOT_HISTORY_SIZE
				];
			}
		}

		return latestUnspentRoots;
	}

	function _getExtDataHash(RewardExtData memory _extData) private pure returns (bytes32) {
		return keccak256(abi.encode(_extData.fee, _extData.recipient, _extData.relayer));
	}

	function _isValidRewardAssetIDs(
		uint32[VALID_REWARD_ASSET_IDS_SIZE] memory _inputIds,
		uint32[VALID_REWARD_ASSET_IDS_SIZE] memory _inputRates
	) private view returns (bool) {
		for (uint256 i = 0; i < _inputIds.length; i++) {
			if (!validRewardAssetIDs[_inputIds[i]]) {
				return false;
			}

			if (!rateExists[_inputIds[i]]) {
				return false;
			}

			if (_inputRates[i] != rates[_inputIds[i]]) {
				return false;
			}
		}

		return true;
	}

	function _isValidSpentRoots(uint256[] memory spentRoots) private view returns (bool) {
		require(spentRoots.length == maxEdges, "Invalid array size");

		// Create an array to track visited edges.
		bool[] memory visitedEdges = new bool[](edgeList.length);

		for (uint256 i = 0; i < spentRoots.length; i++) {
			uint256 spentRoot = spentRoots[i];

			require(spentRoot != 0, "Spent root cannot be zero");

			bool rootFound = false;
			uint256 edgeIndex;

			// Check if the spentRoot is valid for any edge.
			for (uint256 j = 0; j < edgeList.length; j++) {
				if (!visitedEdges[j]) {
					Edge storage edge = edgeList[j];

					for (uint8 k = 0; k < ROOT_HISTORY_SIZE; k++) {
						if (edge.spentRootList[k] == spentRoot) {
							rootFound = true;
							edgeIndex = j;
							break;
						}
					}
				}
			}

			// If the root is not found for any edge, return false.
			if (!rootFound) {
				return false;
			}

			// Mark the edge as visited.
			visitedEdges[edgeIndex] = true;
		}

		return true;
	}

	function isValidSpentRoots(uint256[] memory unspentRoots) external view returns (bool) {
		return _isValidSpentRoots(unspentRoots);
	}

	function _isValidUnspentRoots(uint256[] memory unspentRoots) private view returns (bool) {
		require(unspentRoots.length == maxEdges, "Invalid array size");

		// Create an array to track visited edges.
		bool[] memory visitedEdges = new bool[](edgeList.length);

		for (uint256 i = 0; i < unspentRoots.length; i++) {
			uint256 unspentRoot = unspentRoots[i];

			require(unspentRoot != 0, "Unspent root cannot be zero");

			bool rootFound = false;
			uint256 edgeIndex;

			// Check if the unspentRoot is valid for any edge.
			for (uint256 j = 0; j < edgeList.length; j++) {
				if (!visitedEdges[j]) {
					Edge storage edge = edgeList[j];

					for (uint8 k = 0; k < ROOT_HISTORY_SIZE; k++) {
						if (edge.unspentRootList[k] == unspentRoot) {
							rootFound = true;
							edgeIndex = j;
							break;
						}
					}
				}
			}

			// If the root is not found for any edge, return false.
			if (!rootFound) {
				return false;
			}

			// Mark the edge as visited.
			visitedEdges[edgeIndex] = true;
		}

		return true;
	}

	function isValidUnspentRoots(uint256[] memory unspentRoots) external view returns (bool) {
		return _isValidUnspentRoots(unspentRoots);
	}
}
