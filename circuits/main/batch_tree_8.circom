pragma circom 2.0.0;  

include "../merkle-tree/batchMerkleTreeUpdate.circom";

component main {public [argsHash]} = BatchTreeUpdate(30, 3, nthZero(3));
