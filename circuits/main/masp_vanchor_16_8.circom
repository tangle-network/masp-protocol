pragma circom 2.0.0;  

include "../masp-vanchor/transaction.circom";

component main {public [publicAmount, extDataHash, publicAssetID, publicTokenID, inputNullifier, outputCommitment, chainID, roots, validFeeAssetIDs, feeInputNullifier, feeOutputCommitment]} = Transaction(30, 16, 2, 2, 2, 8, 10);