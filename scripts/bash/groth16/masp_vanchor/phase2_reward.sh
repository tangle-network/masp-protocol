source ./scripts/bash/groth16/phase2_circuit_groth16.sh

move_verifiers_and_metadata_reward () {
    local indir="$1" anchor_type="$2" anchor_size="$3" tree_height="$4"
    local verifier_rename="VerifierReward_${tree_height}_${anchor_size}"

    mkdir -p packages/masp-anchor-contracts/contracts/verifiers/$anchor_type
    cp $indir/verifier.sol packages/masp-anchor-contracts/contracts/verifiers/$anchor_type/${verifier_rename}.sol
    sed -i 's/contract Verifier/contract '$verifier_rename'/g' packages/masp-anchor-contracts/contracts/verifiers/$anchor_type/${verifier_rename}.sol
    sed -i 's/pragma solidity ^0.6.11;/pragma solidity ^0.8.18;/g' packages/masp-anchor-contracts/contracts/verifiers/$anchor_type/${verifier_rename}.sol
}

compile_phase2 ./solidity-fixtures/solidity-fixtures/reward_2/30 reward_30_2 ./artifacts/circuits/reward_2
move_verifiers_and_metadata_reward ./solidity-fixtures/solidity-fixtures/reward_2/30 reward_2 2 30

compile_phase2 ./solidity-fixtures/solidity-fixtures/reward_8/30 reward_30_8 ./artifacts/circuits/reward_8
move_verifiers_and_metadata_reward ./solidity-fixtures/solidity-fixtures/reward_8/30 reward_8 8 30