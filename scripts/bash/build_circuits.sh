#!/bin/bash

compile () {
    local outdir="$1" circuit="$2"
    mkdir -p artifacts/circuits/$outdir
    echo "circuits/main/$circuit.circom"
    ~/.cargo/bin/circom --r1cs --wasm --sym \
        -o artifacts/circuits/$outdir \
        circuits/main/$circuit.circom
    echo -e "Done!\n"
}

copy_to_fixtures () {
    local circuit_type="$1" circuit="$2" size="$3"
    mkdir -p solidity-fixtures/solidity-fixtures/$circuit_type/$size
    cp artifacts/circuits/$circuit_type/$circuit.sym solidity-fixtures/solidity-fixtures/$circuit_type/$size/$circuit.sym
    cp artifacts/circuits/$circuit_type/$circuit.r1cs solidity-fixtures/solidity-fixtures/$circuit_type/$size/$circuit.r1cs
    cp artifacts/circuits/$circuit_type/$circuit\_js/$circuit.wasm solidity-fixtures/solidity-fixtures/$circuit_type/$size/$circuit.wasm
    cp artifacts/circuits/$circuit_type/$circuit\_js/witness_calculator.js solidity-fixtures/solidity-fixtures/$circuit_type/$size/${circuit}_witness_calculator.cjs
}

run_batch_tree () {
    local size="$1"
    echo "Compiling batch insertion for $size leafs (levels=$(($size/2)))"
    compile batch_tree batch_tree_$size $size
    copy_to_fixtures batch_tree batch_tree_$size $size
}

run_masp_vanchor () {
    local size="$1"
    echo "Compiling Webb style multi-asset Poseidon vanchor $size circuit w/ 2 inputs"
    compile masp_vanchor masp_vanchor_2_${size} $size
    compile masp_vanchor masp_vanchor_16_${size} $size
    copy_to_fixtures masp_vanchor masp_vanchor_2_${size} $size
    copy_to_fixtures masp_vanchor masp_vanchor_16_${size} $size
}

run_reward () {
    local size="$1" height="$2"
    echo "Compiling anonimity mining circuit $height $size"
    compile reward reward_${height}_${size} $size
    copy_to_fixtures reward reward_${height}_${size} $size
}

run_swap () {
    local size="$1" height="$2"
    echo "Compiling swap circuit $height $size"
    compile swap swap_${height}_${size} $size
    copy_to_fixtures swap swap_${height}_${size} $size
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
    --circuit=masp2)
        run_masp_vanchor 2
        ;;
    --circuit=masp8)
        run_masp_vanchor 8
        ;;
    --circuit=reward2)
        run_reward 2 30
        ;;
    --circuit=reward8)
        run_reward 8 30
        ;;
    --circuit=swap2)
        run_swap 2 30
        ;;
    --circuit=swap8)
        run_swap 8 30
        ;;
    *)
        for size in 4 8 16 32; do
            run_batch_tree $size
        done
        for size in 2 8; do
            run_masp_vanchor $size
            run_reward $size 30
            run_swap $size 30
        done
        ;;
esac

trap 'echo "Process interrupted"; exit' SIGINT
