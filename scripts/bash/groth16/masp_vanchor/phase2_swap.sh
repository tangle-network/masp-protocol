source ./scripts/bash/groth16/phase2_circuit_groth16.sh

move_verifiers_and_metadata_swap () {
    local indir="$1" anchor_type="$2" anchor_size="$3" tree_height="$4"
    local verifier_rename="VerifierSwap_${tree_height}_${anchor_size}"

    mkdir -p packages/masp-anchor-contracts/contracts/verifiers/$anchor_type
    cp $indir/verifier.sol packages/masp-anchor-contracts/contracts/verifiers/$anchor_type/${verifier_rename}.sol
    sed -i 's/contract Verifier/contract '$verifier_rename'/g' packages/masp-anchor-contracts/contracts/verifiers/$anchor_type/${verifier_rename}.sol
    sed -i 's/pragma solidity ^0.6.11;/pragma solidity ^0.8.18;/g' packages/masp-anchor-contracts/contracts/verifiers/$anchor_type/${verifier_rename}.sol
}

compile_phase2 ./solidity-fixtures/solidity-fixtures/swap_2/30 swap_30_2 ./artifacts/circuits/swap_2
move_verifiers_and_metadata_swap ./solidity-fixtures/solidity-fixtures/swap_2/30 swap_2 2 30

compile_phase2 ./solidity-fixtures/solidity-fixtures/swap_8/30 swap_30_8 ./artifacts/circuits/swap_8
move_verifiers_and_metadata_swap ./solidity-fixtures/solidity-fixtures/swap_8/30 swap_8 8 30