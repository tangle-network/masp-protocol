pragma circom 2.0.0;  

include "../masp-vanchor/transaction.circom";

component main {public [publicAmount, extDataHash, publicAssetID, publicTokenID, inputNullifier, outputCommitment, chainID, roots, validFeeAssetIDs, feeInputNullifier, feeOutputCommitment]} = Transaction(30, 2, 2, 2, 2, 2, 10);