pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../merkle-tree/manyMerkleProof.circom";
include "./key.circom";
include "./nullifier.circom";
include "./record.circom";

// circuit for the equality of 2 binary arrays of size N, 
// also with the condition that 1 appears once in each array.
template BinaryArrayEquality(N) {
    signal input array1[N];
    signal input array2[N];
    signal output equal;

    signal isDifferent[N];
    signal onesArray1[N];
    signal onesArray2[N];
    signal equality[N];

    // Ensure elements are binary and count the number of '1's in each array.
    for (var i = 0; i < N; i++) {
        array1[i] * (1 - array1[i]) === 0;
        array2[i] * (1 - array2[i]) === 0;

        // XOR equivalent for binary values
        isDifferent[i] <== array1[i] + array2[i] - 2 * array1[i] * array2[i];

        if (i == 0) {
            onesArray1[i] <== array1[i];
            onesArray2[i] <== array2[i];
            equality[i] <== 1 - isDifferent[i];
        } else {
            onesArray1[i] <== onesArray1[i - 1] + array1[i];
            onesArray2[i] <== onesArray2[i - 1] + array2[i];
            equality[i] <== equality[i - 1] * (1 - isDifferent[i]);
        }
    }

    // Ensure there is exactly one '1' in each array.
    onesArray1[N - 1] === 1;
    onesArray2[N - 1] === 1;

    // The last element of the equality array represents the overall equality of the two arrays.
    equal <== equality[N - 1];
}

template Reward(levels, zeroLeaf, length, rewardListLength) {
    // Public inputs
    // fee is subtracted from "anonymityRewardPoints" while paying the relayer
    signal input anonymityRewardPoints;
    signal input rewardNullifier;
    // fee and recipient is included in extData
    signal input extDataHash;
    signal input validRewardAssetIDs[rewardListLength];
    signal input rates[rewardListLength];

    signal input selectedRewardRate;

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
    signal input spentRoots[length]; // Public inputs
    signal input spentPathIndices;
    signal input spentPathElements[levels];

    // inputs prefixed with spent correspond to the deposited UTXO
    signal input unspentTimestamp;
    signal input unspentRoots[length]; // Public inputs
    signal input unspentPathIndices;
    signal input unspentPathElements[levels];

    // TODO: Constrain time range to be less than 2^32
    // TODO: Check how many bits we should use here
    // 32 bit value is enough for 136 years
    component timeRangeCheck = Num2Bits(32);
    timeRangeCheck.in <== spentTimestamp - unspentTimestamp;

    // Check if selectedRewardRate is present in the rates array
    // Check if the note AssetID is present in the validRewardAssetIDs array
    component assetIDEquals[rewardListLength];
    component rateEquals[rewardListLength];
    signal assetIDEqualsResult[rewardListLength];
    signal rateEqualsResult[rewardListLength];

    for (var i = 0; i < rewardListLength; i++) {
        assetIDEquals[i] = IsEqual();
        assetIDEquals[i].in[0] <== noteAssetID;
        assetIDEquals[i].in[1] <== validRewardAssetIDs[i];
        assetIDEqualsResult[i] <== assetIDEquals[i].out;

        rateEquals[i] = IsEqual();
        rateEquals[i].in[0] <== selectedRewardRate;
        rateEquals[i].in[1] <== rates[i];
        rateEqualsResult[i] <== rateEquals[i].out;
    }

    // Now check if the assetID and selectedRewardRate are present in the respective
    // validRewardAssetIDs and rates array at same index, that means both of 
    // the arrays are equal and each contain '1' only once. and at same index.
    component binaryArrayEquality = BinaryArrayEquality(rewardListLength);
    binaryArrayEquality.array1 <== assetIDEqualsResult;
    binaryArrayEquality.array2 <== rateEqualsResult;
    binaryArrayEquality.equal === 1;

    // Check amount invariant
    signal intermediateRewardValue;
    intermediateRewardValue <== selectedRewardRate * (spentTimestamp - unspentTimestamp);
    anonymityRewardPoints === intermediateRewardValue * noteAmount;

    // Check that amounts fit into 248 bits to prevent overflow
    // Fee range is checked by the smart contract
    component anonymityRewardPointsCheck = Num2Bits(248);
    anonymityRewardPointsCheck.in <== anonymityRewardPoints;

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
