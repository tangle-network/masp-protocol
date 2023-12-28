source ./scripts/bash/groth16/phase2_circuit_groth16.sh

move_verifiers_and_metadata_batch_insert () {
    local indir="$1" size="$2" circuit_type="$3"

    mkdir -p packages/masp-anchor-contracts/contracts/verifiers/$circuit_type
    cp $indir/${circuit_type}_${size}_verifier.sol packages/masp-anchor-contracts/contracts/verifiers/$circuit_type/VerifierBatch_"$size".sol
    perl -i -pe 's/contract Verifier/contract VerifierBatch_'$size'/g' packages/masp-anchor-contracts/contracts/verifiers/$circuit_type/VerifierBatch_"$size".sol
    perl -i -pe 's/pragma solidity \^0.6.11;/pragma solidity \^0.8.18;/g' packages/masp-anchor-contracts/contracts/verifiers/$circuit_type/VerifierBatch_"$size".sol
}

compile_phase2 solidity-fixtures/solidity-fixtures/batch_tree/4 batch_tree_4 ./artifacts/circuits/batch_tree
move_verifiers_and_metadata_batch_insert solidity-fixtures/solidity-fixtures/batch_tree/4 4 batch_tree

compile_phase2 solidity-fixtures/solidity-fixtures/batch_tree/8 batch_tree_8 ./artifacts/circuits/batch_tree
move_verifiers_and_metadata_batch_insert solidity-fixtures/solidity-fixtures/batch_tree/8 8 batch_tree

compile_phase2 solidity-fixtures/solidity-fixtures/batch_tree/16 batch_tree_16 ./artifacts/circuits/batch_tree
move_verifiers_and_metadata_batch_insert solidity-fixtures/solidity-fixtures/batch_tree/16 16 batch_tree

compile_phase2 solidity-fixtures/solidity-fixtures/batch_tree/32 batch_tree_32 ./artifacts/circuits/batch_tree
move_verifiers_and_metadata_batch_insert solidity-fixtures/solidity-fixtures/batch_tree/32 32 batch_tree
