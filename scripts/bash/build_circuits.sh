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
    mkdir -p packages/contracts/solidity-fixtures/solidity-fixtures/$anchorType
    mkdir -p packages/contracts/solidity-fixtures/solidity-fixtures/$anchorType/$size
    cp artifacts/circuits/$outdir/$circuit.sym packages/contracts/solidity-fixtures/solidity-fixtures/$anchorType/$size/$circuit.sym
    cp artifacts/circuits/$outdir/$circuit.r1cs packages/contracts/solidity-fixtures/solidity-fixtures/$anchorType/$size/$circuit.r1cs
    cp artifacts/circuits/$outdir/$circuit\_js/$circuit.wasm packages/contracts/solidity-fixtures/solidity-fixtures/$anchorType/$size/$circuit.wasm
    cp artifacts/circuits/$outdir/$circuit\_js/witness_calculator.js packages/contracts/solidity-fixtures/solidity-fixtures/$anchorType/$size/witness_calculator.cjs
}

###
# WEBB BATCH TREE UPDATER
###

echo "Compiling batch insertion for 4 leafs (levels=2)"
compile batch_tree_4 batchMerkleTreeUpdate_4 4
copy_to_fixtures batch_tree_4 batchMerkleTreeUpdate_4 4 batch-tree

echo "Compiling batch insertion for 8 leafs (levels=3)"
compile batch_tree_8 batchMerkleTreeUpdate_8 8
copy_to_fixtures batch_tree_8 batchMerkleTreeUpdate_8 8 batch-tree

echo "Compiling batch insertion for 16 leafs (levels=4)"
compile batch_tree_16 batchMerkleTreeUpdate_16 16
copy_to_fixtures batch_tree_16 batchMerkleTreeUpdate_16 16 batch-tree

echo "Compiling batch insertion for 32 leafs (levels=5)"
compile batch_tree_32 batchMerkleTreeUpdate_32 32
copy_to_fixtures batch_tree_32 batchMerkleTreeUpdate_32 32 batch-tree

echo "Compiling batch insertion for 64 leafs (levels=6)"
compile batch_tree_64 batchMerkleTreeUpdate_64 64
copy_to_fixtures batch_tree_64 batchMerkleTreeUpdate_64 64 batch-tree

###
# WEBB MASP-VANCHORS
###

echo "Compiling Webb style multi-asset Poseidon vanchor 2 circuit w/ 2 inputs"
compile masp_vanchor_2 masp_vanchor_2_2 2
copy_to_fixtures masp_vanchor_2 masp_vanchor_2_2 2 masp_vanchor_2

echo "Compiling Webb style multi-asset Poseidon vanchor 8 circuit w/ 2 inputs"
compile masp_vanchor_2 masp_vanchor_2_8 8
copy_to_fixtures masp_vanchor_2 masp_vanchor_2_8 8 masp_vanchor_2

echo "Compiling Webb style multi-asset Poseidon vanchor 2 circuit w/ 16 inputs"
compile masp_vanchor_16 masp_vanchor_16_2 2
copy_to_fixtures masp_vanchor_16 masp_vanchor_16_2 2 masp_vanchor_16

echo "Compiling Webb style multi-asset Poseidon vanchor 8 circuit w/ 16 inputs"
compile masp_vanchor_16 masp_vanchor_16_8 8
copy_to_fixtures masp_vanchor_16 masp_vanchor_16_8 8 masp_vanchor_16

###
# WEBB MASP VANCHOR FOREST
###

# echo "Compiling Webb style multi-asset vanchor forest 2 circuit w/ 2 inputs"
# compile vanchor_forest_2 vanchor_forest_2_2 2
# copy_to_fixtures vanchor_forest_2 vanchor_forest_2_2 2 vanchor_forest_2

# echo "Compiling Webb style multi-asset vanchor forest 8 circuit w/ 2 inputs"
# compile vanchor_forest_2 vanchor_forest_2_8 8
# copy_to_fixtures vanchor_forest_2 vanchor_forest_2_8 8 vanchor_forest_2
# #
# echo "Compiling Webb style multi-asset vanchor forest 2 circuit w/ 16 inputs"
# compile vanchor_forest_16 vanchor_forest_16_2 2
# copy_to_fixtures vanchor_forest_16 vanchor_forest_16_2 2 vanchor_forest_16 
# #
# echo "Compiling Webb style multi-asset vanchor forest 8 circuit w/ 2 inputs"
# compile vanchor_forest_16 vanchor_forest_16_8 8
# copy_to_fixtures vanchor_forest_16 vanchor_forest_16_8 8 vanchor_forest_16 


###
# WEBB ANONIMITY MINING REWARD SYSTEM
###

echo "Compiling anonimity mining circuit"
compile reward_2 reward_30_2 30
copy_to_fixtures reward_2 reward_30_2 30 reward_2

echo "Compiling anonimity mining circuit"
compile reward_8 reward_30_8 30
copy_to_fixtures reward_8 reward_30_8 30 reward_8

# ###
# # WEBB MASP SWAP SYSTEM
# ###

echo "Compiling swap circuit 20 2"
compile swap_2 swap_20_2 20
copy_to_fixtures swap_2 swap_20_2 20 swap_2

echo "Compiling swap circuit 20 8"
compile swap_8 swap_20_8 20
copy_to_fixtures swap_8 swap_20_8 20 swap_8

echo "Compiling swap circuit 30 2"
compile swap_2 swap_30_2 30
copy_to_fixtures swap_2 swap_30_2 30 swap_2

echo "Compiling swap circuit 30 8"
compile swap_8 swap_30_8 30
copy_to_fixtures swap_8 swap_30_8 30 swap_8