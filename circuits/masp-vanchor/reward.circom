pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../merkle-tree/manyMerkleProof.circom";
include "../merkle-tree/merkleTree.circom";
include "../set/membership.circom";
include "./key.circom";
include "./nullifier.circom";
include "./record.circom";
include "./babypow.circom";

template Reward(levels, zeroLeaf, length, sizeWhitelistedAssetIDList) {
	signal input rate;
	// fee is subtracted from "anonymityRewardPoints" while paying the relayer
	signal input anonymityRewardPoints;
	signal input rewardNullifier;
	// fee and recipient is included in extData
	signal input extDataHash;

	signal input whitelistedAssetIDs[sizeWhitelistedAssetIDList];

	// MASP Spent Note for which reward points are being claimed
	signal input noteChainID;
	signal input noteAmount;
	signal input noteAssetID;
	signal input noteTokenID;
	signal input note_ak_X;
	signal input note_ak_Y;
	signal input noteBlinding;
	signal input notePathIndices;

	// inputs prefixed with spent correspond to the already spent UTXO
	signal input spentTimestamp;
	signal input spentRoots[length];
	signal input spentPathIndices;
	signal input spentPathElements[levels];

	// inputs prefixed with spent correspond to the deposited UTXO
	signal input unspentTimestamp;
	signal input unspentRoots[length];
	signal input unspentPathIndices;
	signal input unspentPathElements[levels];

	// Check amount invariant
	signal intermediateRewardValue;
	intermediateRewardValue <== rate * (spentTimestamp - unspentTimestamp);
	anonymityRewardPoints === intermediateRewardValue * noteAmount;

	// Check that amounts fit into 248 bits to prevent overflow
	// Fee range is checked by the smart contract
	component anonymityRewardPointsCheck = Num2Bits(248);
	anonymityRewardPointsCheck.in <== anonymityRewardPoints;

	// TODO: Constrain time range to be less than 2^32
	// TODO: Check how many bits we should use here
	// 32 bit value is enough for 136 years
	component timeRangeCheck = Num2Bits(32);
	timeRangeCheck.in <== spentTimestamp - unspentTimestamp;

    // Check if the note AssetID is allowable
    component membership = SetMembership(sizeWhitelistedAssetIDList);
    membership.element <== noteAssetID;
    for (var i = 0; i < sizeWhitelistedAssetIDList; i++) {
        membership.set[i] <== whitelistedAssetIDs[i];
    }

	// === check deposit and withdrawal ===
	// Compute commitment and nullifier

	component noteKeyComputer = Key();
	noteKeyComputer.ak_X <== note_ak_X;
	noteKeyComputer.ak_Y <== note_ak_Y;

	// Compute MASP commitment
	// MASP Inner Partial Commitment
	component noteInnerPartialCommitmentHasher = InnerPartialRecord();
	noteInnerPartialCommitmentHasher.blinding <== noteBlinding;
	// MASP Partial Commitment
	component notePartialCommitmentHasher = PartialRecord();
	notePartialCommitmentHasher.chainID <== noteChainID;
	notePartialCommitmentHasher.pk_X <== noteKeyComputer.pk_X;
	notePartialCommitmentHasher.pk_Y <== noteKeyComputer.pk_Y;
	notePartialCommitmentHasher.innerPartialRecord <== noteInnerPartialCommitmentHasher.innerPartialRecord;
	// MASP Full Commitment
	component noteRecordHasher = Record();
	noteRecordHasher.assetID <== noteAssetID;
	noteRecordHasher.tokenID <== noteTokenID;
	noteRecordHasher.amount <== noteAmount;
	noteRecordHasher.partialRecord <== notePartialCommitmentHasher.partialRecord;
	// MASP Nullifier
	component noteNullifierHasher = Nullifier();
	noteNullifierHasher.ak_X <== note_ak_X;
	noteNullifierHasher.ak_Y <== note_ak_Y;
	noteNullifierHasher.record <== noteRecordHasher.record;

	// Compute deposit commitment
	component unspentHasher = Poseidon(2);
	unspentHasher.inputs[0] <== noteRecordHasher.record;
	unspentHasher.inputs[1] <== unspentTimestamp;
	// Verify that deposit commitment exists in the tree
	component unspentTree = ManyMerkleProof(levels, length);
	unspentTree.leaf <== unspentHasher.out;
	unspentTree.pathIndices <== unspentPathIndices;
	for (var i = 0; i < levels; i++) {
		unspentTree.pathElements[i] <== unspentPathElements[i];
	}
	unspentTree.isEnabled <== 1;
	for (var i = 0; i < length; i++) {
		unspentTree.roots[i] <== unspentRoots[i];
	}

	// Compute withdrawal commitment
	component spentHasher = Poseidon(2);
	spentHasher.inputs[0] <== noteNullifierHasher.nullifier;
	spentHasher.inputs[1] <== spentTimestamp;
	// Verify that withdrawal commitment exists in the tree
	component spentTree = ManyMerkleProof(levels, length);
	spentTree.leaf <== spentHasher.out;
	spentTree.pathIndices <== spentPathIndices;
	for (var i = 0; i < levels; i++) {
		spentTree.pathElements[i] <== spentPathElements[i];
	}
	spentTree.isEnabled <== 1;
	for (var i = 0; i < length; i++) {
		spentTree.roots[i] <== spentRoots[i];
	}

	// Compute reward nullifier
	component rewardNullifierHasher = Poseidon(2);
	rewardNullifierHasher.inputs[0] <== noteNullifierHasher.nullifier;
	rewardNullifierHasher.inputs[1] <== notePathIndices;
	rewardNullifierHasher.out === rewardNullifier;

	// Add hidden signals to make sure that tampering with recipient or fee will invalidate the snark proof
	// Most likely it is not required, but it's better to stay on the safe side and it only takes 2 constraints
	// Squares are used to prevent optimizer from removing those constraints
	signal extDataHashSquare;
	extDataHashSquare <== extDataHash * extDataHash;
}
