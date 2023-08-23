#!/bin/bash

compile () {
    local outdir="$1" circuit="$2" size="$3"
    mkdir -p build/$outdir
    mkdir -p build/$outdir/$size
    mkdir -p artifacts/circuits/$outdir
    echo "circuits/test/$circuit.circom"
    ~/.cargo/bin/circom --r1cs --wasm --sym \
        -o artifacts/circuits/$outdir \
        circuits/test/$circuit.circom
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


# ###
# # WEBB MASP SWAP SYSTEM
# ###

echo "Compiling swap circuit 30 2"
compile swap_2 swap_30_2 30
copy_to_fixtures swap_2 swap_30_2 30 swap_2

echo "Compiling swap circuit 30 8"
compile swap_8 swap_30_8 30
copy_to_fixtures swap_8 swap_30_8 30 swap_8