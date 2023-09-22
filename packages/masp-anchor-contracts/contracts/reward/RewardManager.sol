/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
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

	mapping(bytes32 => bool) public rewardNullifiers;
	uint256 public rate;

	uint32[WHITELISTED_ASSET_ID_LIST_SIZE] public whitelistedAssetIDs;

	struct Edge {
		uint256[ROOT_HISTORY_SIZE] spentRootList;
		uint256[ROOT_HISTORY_SIZE] unspentRootList;
		uint8 currentIndex;
	}

	uint8 public maxEdges;
	mapping(uint256 => uint256) public chainIdToEdgeListIndex;
	mapping(uint256 => bool) public edgeExistsForChain;
	Edge[] public edgeList;

	event EdgeAdded(uint256 indexed chainId, uint256 indexed edgeIndex);
	event EdgeUpdated(uint256 indexed oldChainId, uint256 indexed newChainId);
	event RootAddedToSpentList(uint256 indexed chainId, uint256 root);
	event RootAddedToUnspentList(uint256 indexed chainId, uint256 root);

	event RateUpdated(uint256 newRate);
	// Event to log changes in whitelistedAssetIDs.
	event whitelistedAssetIDsUpdated(uint32[WHITELISTED_ASSET_ID_LIST_SIZE] newwhitelistedAssetIDs);

	modifier onlyGovernance() {
		require(msg.sender == governance, "Only governance can perform this action");
		_;
	}

	constructor(
		address _rewardSwap,
		address _rewardVerifier,
		address _governance,
		uint8 _maxEdges,
		uint256 _rate,
		uint32[WHITELISTED_ASSET_ID_LIST_SIZE] memory _initialwhitelistedAssetIDs
	) {
		rewardSwap = IRewardSwap(_rewardSwap);
		rewardVerifier = IRewardVerifier(_rewardVerifier);
		governance = _governance;
		rate = _rate;
		whitelistedAssetIDs = _initialwhitelistedAssetIDs;
		maxEdges = _maxEdges;
	}

	function reward(
		bytes memory _proof,
		RewardPublicInputs memory _publicInputs,
		RewardExtData memory _extData
	) public {
		(
			bytes memory _encodedInputs,
			uint32[WHITELISTED_ASSET_ID_LIST_SIZE] memory _whitelistedAssetIDs,
			uint256[] memory _spentRoots,
			uint256[] memory _unspentRoots
		) = RewardEncodeInputs._encodeInputs(_publicInputs, maxEdges);

		require(_publicInputs.rate == rate && _publicInputs.rate > 0, "Invalid reward rate");
		require(
			!rewardNullifiers[bytes32(_publicInputs.rewardNullifier)],
			"Reward has been already spent"
		);
		require(
			_publicInputs.extDataHash ==
				uint256(_getExtDataHash(_extData)) % SNARK_SCALAR_FIELD_SIZE,
			"Incorrect external data hash"
		);
		require(_isValidWhitelistedIds(_whitelistedAssetIDs), "Invalid asset IDs");
		require(_isValidSpentRoots(_spentRoots), "Invalid spent roots");
		require(_isValidUnspentRoots(_unspentRoots), "Invalid spent roots");

		// Verify the proof
		require(
			IRewardVerifier(rewardVerifier).verifyProof(_proof, _encodedInputs, maxEdges),
			"Invalid reward proof"
		);

		// mark that reward has been awarded
		rewardNullifiers[bytes32(_publicInputs.rewardNullifier)] = true;

		// Transfer to the recipient
		uint256 rewardAmountMinusFee = _publicInputs.rewardAmount - _extData.fee;
		if (rewardAmountMinusFee > 0) {
			rewardSwap.swap(_extData.recipient, rewardAmountMinusFee);
		}
		// Transfer to the relayer
		if (_extData.fee > 0) {
			rewardSwap.swap(_extData.relayer, _extData.fee);
		}
	}

	function setRates(uint256 _rate) external onlyGovernance nonReentrant {
		rate = _rate;
		emit RateUpdated(rate);
	}

	function setPoolWeight(uint256 _newWeight) external onlyGovernance nonReentrant {
		rewardSwap.setPoolWeight(_newWeight);
	}

	// Function to modify the whitelistedAssetIDs.
	function updatewhitelistedAssetIDs(
		uint32[WHITELISTED_ASSET_ID_LIST_SIZE] memory _newwhitelistedAssetIDs
	) external onlyGovernance nonReentrant {
		whitelistedAssetIDs = _newwhitelistedAssetIDs;
		emit whitelistedAssetIDsUpdated(_newwhitelistedAssetIDs);
	}

	// Getter function to retrieve whitelistedAssetIDs.
	function getwhitelistedAssetIDs()
		external
		view
		returns (uint32[WHITELISTED_ASSET_ID_LIST_SIZE] memory)
	{
		return whitelistedAssetIDs;
	}

	function _getExtDataHash(RewardExtData memory _extData) private pure returns (bytes32) {
		return keccak256(abi.encode(_extData.fee, _extData.recipient, _extData.relayer));
	}

	function _isValidWhitelistedIds(
		uint32[WHITELISTED_ASSET_ID_LIST_SIZE] memory _inputIds
	) private view returns (bool) {
		require(_inputIds.length == whitelistedAssetIDs.length, "Input list length does not match");

		for (uint256 i = 0; i < _inputIds.length; i++) {
			if (_inputIds[i] != whitelistedAssetIDs[i]) {
				return false;
			}
		}

		return true;
	}

	// Add a new edge.
	function addEdge(uint256 chainId) external onlyGovernance nonReentrant {
		require(!edgeExistsForChain[chainId], "Edge for this chainId already exist");
		require(edgeList.length < maxEdges, "Maximum number of edges reached");

		Edge memory newEdge;
		newEdge.currentIndex = 0;
		edgeList.push(newEdge);

		uint256 edgeIndex = edgeList.length - 1;
		edgeExistsForChain[chainId] = true;
		chainIdToEdgeListIndex[chainId] = edgeIndex;
		emit EdgeAdded(chainId, edgeIndex);
	}

	// Update an existing edge with a new chainId.
	function updateEdge(
		uint256 oldChainId,
		uint256 newChainId
	) external onlyGovernance nonReentrant {
		require(edgeExistsForChain[oldChainId], "Edge for old chainId does not exist");
		require(!edgeExistsForChain[newChainId], "Edge for new chainId already exists");
		uint256 edgeIndex = chainIdToEdgeListIndex[oldChainId];
		chainIdToEdgeListIndex[oldChainId] = 0;
		chainIdToEdgeListIndex[newChainId] = edgeIndex;
		edgeExistsForChain[oldChainId] = false;
		edgeExistsForChain[newChainId] = true;

		// Clear the content of the old chain's spent and unspent root lists
		Edge storage edge = edgeList[edgeIndex];
		for (uint8 i = 0; i < ROOT_HISTORY_SIZE; i++) {
			edge.spentRootList[i] = 0;
			edge.unspentRootList[i] = 0;
		}

		emit EdgeUpdated(oldChainId, newChainId);
	}

	// Add a root to the spent list of an existing edge.
	function addRootToSpentList(
		uint256 chainId,
		uint256 root
	) external onlyGovernance nonReentrant {
		require(edgeExistsForChain[chainId], "Edge for this chainId does not exist");
		Edge storage edge = edgeList[chainIdToEdgeListIndex[chainId]];
		edge.spentRootList[edge.currentIndex] = root;
		edge.currentIndex = (edge.currentIndex + 1) % ROOT_HISTORY_SIZE;
		emit RootAddedToSpentList(chainId, root);
	}

	// Add a root to the unspent list of an existing edge.
	function addRootToUnspentList(
		uint256 chainId,
		uint256 root
	) external onlyGovernance nonReentrant {
		require(edgeExistsForChain[chainId], "Edge for this chainId does not exist");
		Edge storage edge = edgeList[chainIdToEdgeListIndex[chainId]];
		edge.unspentRootList[edge.currentIndex] = root;
		edge.currentIndex = (edge.currentIndex + 1) % ROOT_HISTORY_SIZE;
		emit RootAddedToUnspentList(chainId, root);
	}

	function getLatestSpentRoots() external view returns (uint256[] memory) {
		uint256[] memory latestSpentRoots = new uint256[](maxEdges);

		for (uint256 i = 0; i < edgeList.length; i++) {
			uint256 edgeIndex = i;
			uint256 currentIndex = edgeList[edgeIndex].currentIndex;

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

	function getLatestUnspentRoots() external view returns (uint256[] memory) {
		uint256[] memory latestUnspentRoots = new uint256[](maxEdges);

		for (uint256 i = 0; i < edgeList.length; i++) {
			uint256 edgeIndex = i;
			uint256 currentIndex = edgeList[edgeIndex].currentIndex;

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

	function _isValidSpentRoots(uint256[] memory spentRoots) private view returns (bool) {
		require(spentRoots.length == maxEdges, "_isValidSpentRoots:Invalid array size");

		// Check for uniqueness of spentRoots
		require(areUnique(spentRoots), "Duplicate spentRoots found");

		for (uint256 i = 0; i < spentRoots.length; i++) {
			uint256 spentRoot = spentRoots[i];
			require(spentRoot != 0, "Spent root cannot be zero");

			// Check if the spentRoot is valid for more than one edge
			uint256 validEdgeCount = 0;
			for (uint256 j = 0; j < edgeList.length; j++) {
				if (isSpentRootValid(j, spentRoot)) {
					validEdgeCount++;
					if (validEdgeCount > 1) {
						// If the spentRoot is valid for more than one edge, it's a violation
						return false;
					}
				}
			}

			// If the spentRoot is not valid for any edge, it's a violation
			if (validEdgeCount == 0) {
				return false;
			}
		}

		return true;
	}

	function _isValidUnspentRoots(uint256[] memory unspentRoots) private view returns (bool) {
		require(unspentRoots.length == maxEdges, "_isValidUnspentRoots:Invalid array size");
		require(areUnique(unspentRoots), "Duplicate unspentRoots found");

		for (uint256 i = 0; i < unspentRoots.length; i++) {
			uint256 unspentRoot = unspentRoots[i];
			require(unspentRoot != 0, "Unspent root cannot be zero");

			bool isValid = false;
			for (uint256 j = 0; j < edgeList.length; j++) {
				if (isUnspentRootValid(j, unspentRoot)) {
					isValid = true;
					break;
				}
			}

			if (!isValid) {
				return false;
			}
		}

		return true;
	}

	// Check if a spent root is valid for a specific edge.
	function isSpentRootValid(uint256 chainId, uint256 spentRoot) internal view returns (bool) {
		uint256 edgeIndex = chainIdToEdgeListIndex[chainId];
		Edge storage edge = edgeList[edgeIndex];
		for (uint8 i = 0; i < ROOT_HISTORY_SIZE; i++) {
			if (edge.spentRootList[i] == spentRoot) {
				return true;
			}
		}
		return false;
	}

	// Check if an unspent root is valid for a specific edge.
	function isUnspentRootValid(uint256 chainId, uint256 unspentRoot) internal view returns (bool) {
		uint256 edgeIndex = chainIdToEdgeListIndex[chainId];
		Edge storage edge = edgeList[edgeIndex];
		for (uint8 i = 0; i < ROOT_HISTORY_SIZE; i++) {
			if (edge.unspentRootList[i] == unspentRoot) {
				return true;
			}
		}
		return false;
	}

	// Check if an array contains unique elements.
	function areUnique(uint256[] memory arr) internal pure returns (bool) {
		for (uint256 i = 0; i < arr.length; i++) {
			for (uint256 j = i + 1; j < arr.length; j++) {
				if (arr[i] == arr[j]) {
					return false;
				}
			}
		}
		return true;
	}
}
