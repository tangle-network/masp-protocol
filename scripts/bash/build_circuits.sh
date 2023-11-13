#!/bin/bash

compile () {
    local outdir="$1" circuit="$2" size="$3"
    mkdir -p build/$outdir
    mkdir -p build/$outdir/$size
    mkdir -p artifacts/circuits/$outdir
    echo "circuits/main/$circuit.circom"
    ~/.cargo/bin/circom --r1cs --wasm --sym \
        -o artifacts/circuits/$outdir \
        circuits/main/$circuit.circom
    echo -e "Done!\n"
}

copy_to_fixtures () {
    local outdir="$1" circuit="$2" size="$3" anchorType="$4" 
    mkdir -p solidity-fixtures/solidity-fixtures/$anchorType
    mkdir -p solidity-fixtures/solidity-fixtures/$anchorType/$size
    cp artifacts/circuits/$outdir/$circuit.sym solidity-fixtures/solidity-fixtures/$anchorType/$size/$circuit.sym
    cp artifacts/circuits/$outdir/$circuit.r1cs solidity-fixtures/solidity-fixtures/$anchorType/$size/$circuit.r1cs
    cp artifacts/circuits/$outdir/$circuit\_js/$circuit.wasm solidity-fixtures/solidity-fixtures/$anchorType/$size/$circuit.wasm
    cp artifacts/circuits/$outdir/$circuit\_js/witness_calculator.js solidity-fixtures/solidity-fixtures/$anchorType/$size/witness_calculator.cjs
}

run_batch_tree () {
    local size="$1"
    echo "Compiling batch insertion for $size leafs (levels=$(($size/2)))"
    compile batch_tree_$size batchMerkleTreeUpdate_$size $size
    copy_to_fixtures batch_tree_$size batchMerkleTreeUpdate_$size $size batch-tree
}

run_masp_vanchor () {
    local size="$1"
    echo "Compiling Webb style multi-asset Poseidon vanchor $size circuit w/ 2 inputs"
    compile masp_vanchor_2 masp_vanchor_2_$size $size
    copy_to_fixtures masp_vanchor_2 masp_vanchor_2_$size $size masp_vanchor_2
}

run_reward () {
    local size="$1"
    echo "Compiling anonimity mining circuit"
    compile reward_$size reward_30_$size 30
    copy_to_fixtures reward_$size reward_30_$size 30 reward_$size
}

run_swap () {
    local size="$1"
    echo "Compiling swap circuit 30 $size"
    compile swap_$size swap_30_$size 30
    copy_to_fixtures swap_$size swap_30_$size 30 swap_$size
}

case "$1" in
    --circuit=batch4)
        run_batch_tree 4
        ;;
    --circuit=batch8)
        run_batch_tree 8
        ;;
    --circuit=batch16)
        run_batch_tree 16
        ;;
    --circuit=batch32)
        run_batch_tree 32
        ;;
    --circuit=batch64)
        run_batch_tree 64
        ;;
    --circuit=masp2)
        run_masp_vanchor 2
        ;;
    --circuit=masp8)
        run_masp_vanchor 8
        ;;
    --circuit=reward2)
        run_reward 2
        ;;
    --circuit=reward8)
        run_reward 8
        ;;
    --circuit=swap2)
        run_swap 2
        ;;
    --circuit=swap8)
        run_swap 8
        ;;
    *)
        for size in 4 8 16 32 64; do
            run_batch_tree $size
        done
        for size in 2 8; do
            run_masp_vanchor $size
            run_reward $size
            run_swap $size
        done
        ;;
esac
