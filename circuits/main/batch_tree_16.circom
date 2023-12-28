pragma circom 2.0.0;  

include "../merkle-tree/batchMerkleTreeUpdate.circom";

component main {public [argsHash]} = BatchTreeUpdate(30, 4, nthZero(4));
