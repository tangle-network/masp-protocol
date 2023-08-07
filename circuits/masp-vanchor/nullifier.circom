pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";

// Nullfier = Poseidon(ak_X, ak_Y, Record)
template Nullifier() {
    signal input ak_X;
    signal input ak_Y;
    signal input record;
    signal output nullifier;

    component hasher = Poseidon(3);
    hasher.inputs[0] <== ak_X;
    hasher.inputs[1] <== ak_Y;
    hasher.inputs[2] <== record;
    nullifier <== hasher.out;
}