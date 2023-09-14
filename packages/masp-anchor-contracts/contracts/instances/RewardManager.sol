/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IRewardSwap.sol";
import "../interfaces/IRewardVerifier.sol";
import "../interfaces/IMASPProxy.sol";
import "../PublicInputs.sol";
import "../RewardEncodeInputs.sol";

contract RewardManager {
	uint8 public constant ROOT_HISTORY_SIZE = 30;

	IRewardSwap public immutable rewardSwap;
	IRewardVerifier public immutable rewardVerifier;
	address public immutable governance;

	mapping(bytes32 => bool) public rewardNullifiers;
	uint256 public rate;

	uint8 sizeWhitelistedAssetId;
	uint256[] public whiteListedAssetIds;

	struct Edge {
		uint256[ROOT_HISTORY_SIZE] spentRootList;
		uint256[ROOT_HISTORY_SIZE] unspentRootList;
		uint8 currentIndex;
	}

	uint256 public maxEdges;
	mapping(uint256 => uint256) public chainIdToEdgeListIndex;
	mapping(uint256 => bool) public edgeExistsForChain;
	Edge[] public edgeList;

	event EdgeAdded(uint256 indexed chainId);
	event EdgeUpdated(uint256 indexed oldChainId, uint256 indexed newChainId);
	event RootAddedToSpentList(uint256 indexed chainId, uint256 root);
	event RootAddedToUnspentList(uint256 indexed chainId, uint256 root);

	event RateChanged(uint256 assetId, uint256 rate);

	modifier onlyGovernance() {
		require(msg.sender == governance, "Only governance can perform this action");
		_;
	}

	constructor(
		address _rewardSwap,
		address _rewardVerifier,
		address _governance,
		uint256 _rate,
		uint8 _sizeWhitelistedAssetId,
		uint8 _maxEdges
	) {
		rewardSwap = IRewardSwap(_rewardSwap);
		rewardVerifier = IRewardVerifier(_rewardVerifier);
		governance = _governance;
		rate = _rate;
		sizeWhitelistedAssetId = _sizeWhitelistedAssetId;
		maxEdges = _maxEdges;
	}

	function reward(bytes memory _proof, RewardPublicInputs memory _publicInputs) public {
		(
			bytes memory encodedInputs,
			uint256[] memory spentRoots,
			uint256[] memory unspentRoots
		) = RewardEncodeInputs._encodeInputs(_publicInputs, sizeWhitelistedAssetId, maxEdges);

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

	// Add a new edge.
	function addEdge(uint256 chainId) external nonReentrant {
		require(!edgeExistsForChain[chainId], "Edge for this chainId already exist");
		require(edgeList.length < maxEdges, "Maximum number of edges reached");
		edgeList.push(Edge(new uint256[](ROOT_HISTORY_SIZE), new uint256[](ROOT_HISTORY_SIZE), 0));
		chainIdToEdgeListIndex[chainId] = edgeList.length - 1;
		edgeExistsForChain[chainId] = true;
		emit EdgeAdded(chainId);
	}

	// Update an existing edge with a new chainId.
	function updateEdge(uint256 oldChainId, uint256 newChainId) external nonReentrant {
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
	function addRootToSpentList(uint256 chainId, uint256 root) external nonReentrant {
		require(edgeExistsForChain[chainId], "Edge for this chainId does not exist");
		Edge storage edge = edgeList[chainIdToEdgeListIndex[chainId]];
		edge.spentRootList[edge.currentIndex] = root;
		edge.currentIndex = (edge.currentIndex + 1) % ROOT_HISTORY_SIZE;
		emit RootAddedToSpentList(chainId, root);
	}

	// Add a root to the unspent list of an existing edge.
	function addRootToUnspentList(uint256 chainId, uint256 root) external nonReentrant {
		require(edgeExistsForChain[chainId], "Edge for this chainId does not exist");
		Edge storage edge = edgeList[chainIdToEdgeListIndex[chainId]];
		edge.unspentRootList[edge.currentIndex] = root;
		edge.currentIndex = (edge.currentIndex + 1) % ROOT_HISTORY_SIZE;
		emit RootAddedToUnspentList(chainId, root);
	}

	// Check if the spent roots provided in a mapping are valid for the corresponding chains.
	function isValidSpentRoots(
		mapping(uint256 => uint256) calldata chainIdToSpentRoot
	) external view returns (bool) {
		for (uint256 i = 0; i < maxEdges; i++) {
			uint256 chainId = edgeList[i].currentIndex;
			uint256 spentRoot = chainIdToSpentRoot[chainId];
			if (spentRoot != 0 && !isSpentRootValid(i, spentRoot)) {
				return false;
			}
		}
		return true;
	}

	// Check if a spent root is valid for a specific edge.
	function isSpentRootValid(uint256 edgeIndex, uint256 spentRoot) internal view returns (bool) {
		Edge storage edge = edgeList[edgeIndex];
		for (uint8 i = 0; i < ROOT_HISTORY_SIZE; i++) {
			if (edge.spentRootList[i] == spentRoot) {
				return true;
			}
		}
		return false;
	}
}
