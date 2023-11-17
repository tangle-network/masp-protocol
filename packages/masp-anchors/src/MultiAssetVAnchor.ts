import { MultiAssetVAnchorBase } from './MultiAssetVAnchorBase';
import {
  MultiAssetVAnchorBatchTree as MultiAssetVAnchorBatchTreeContract,
  MultiAssetVAnchorBatchTree__factory,
  SwapEncodeInputs__factory,
  MASPVAnchorEncodeInputs__factory,
} from '@webb-tools/masp-anchor-contracts';
import { ProxiedBatchTree } from './ProxiedBatchTree';
import { getChainIdType, MerkleTree, ZkComponents } from '@webb-tools/utils';
import { BigNumber, BigNumberish, ethers } from 'ethers';
import { MaspKey } from './primitives/MaspKey';
import { MaspUtxo } from './primitives/MaspUtxo';
import { Registry } from './tokens';

export class MultiAssetVAnchor extends MultiAssetVAnchorBase {
  public async transactInner(
    assetID: BigNumberish,
    tokenID: BigNumberish,
    wrapUnwrapToken: string,
    inputs: MaspUtxo[],
    outputs: MaspUtxo[],
    fee: BigNumberish, // Most likely 0 because fee will be paid through feeInputs
    feeAssetID: BigNumberish,
    feeTokenID: BigNumberish,
    feeInputs: MaspUtxo[],
    feeOutputs: MaspUtxo[],
    whitelistedAssetIds: BigNumberish[],
    refund: BigNumberish,
    recipient: string,
    relayer: string,
    commitmentTree: MerkleTree,
    signer: ethers.Signer
  ): Promise<ethers.ContractReceipt> {
    // Default UTXO chain ID will match with the configured signer's chain ID
    const evmId = await this.signer.getChainId();
    const chainId = getChainIdType(evmId);
    let dummyInMaspKey = new MaspKey();
    if (inputs.length !== 0) {
      dummyInMaspKey = inputs[0].maspKey;
    }

    let dummyOutMaspKey = new MaspKey();

    let dummyFeeInMaspKey = new MaspKey();
    if (feeInputs.length !== 0) {
      dummyFeeInMaspKey = feeInputs[0].maspKey;
    }

    let dummyFeeOutMaspKey = new MaspKey();

    while (inputs.length < 16) {
      if (inputs.length === 2) break;
      const dummyUtxo = new MaspUtxo(
        BigNumber.from(chainId),
        dummyInMaspKey,
        BigNumber.from(assetID),
        BigNumber.from(tokenID),
        BigNumber.from(0)
      );
      inputs.push(dummyUtxo);
      dummyUtxo.forceSetIndex(BigNumber.from(0));
    }

    while (outputs.length < 2) {
      outputs.push(
        new MaspUtxo(
          BigNumber.from(chainId),
          dummyOutMaspKey,
          BigNumber.from(assetID),
          BigNumber.from(tokenID),
          BigNumber.from(0)
        )
      );
    }

    while (feeInputs.length < 2) {
      const dummyUtxo = new MaspUtxo(
        BigNumber.from(chainId),
        dummyFeeInMaspKey,
        BigNumber.from(feeAssetID),
        BigNumber.from(feeTokenID),
        BigNumber.from(0)
      );
      feeInputs.push(dummyUtxo);
      dummyUtxo.forceSetIndex(BigNumber.from(0));
    }

    while (feeOutputs.length < 2) {
      feeOutputs.push(
        new MaspUtxo(
          BigNumber.from(chainId),
          dummyFeeOutMaspKey,
          BigNumber.from(feeAssetID),
          BigNumber.from(feeTokenID),
          BigNumber.from(0)
        )
      );
    }

    const merkleProofs = inputs.map((x) =>
      MultiAssetVAnchorBase.getMASPMerkleProof(x, commitmentTree)
    );

    const feeMerkleProofs = feeInputs.map((x) =>
      MultiAssetVAnchorBase.getMASPMerkleProof(x, commitmentTree)
    );

    let extAmount = BigNumber.from(fee)
      .add(outputs.reduce((sum, x) => sum.add(x.amount), BigNumber.from(0)))
      .sub(inputs.reduce((sum, x) => sum.add(x.amount), BigNumber.from(0)));

    const { extData, extDataHash } = await this.generateExtData(
      recipient,
      extAmount,
      relayer,
      BigNumber.from(fee),
      BigNumber.from(refund),
      wrapUnwrapToken,
      '0x' + outputs[0].encrypt(outputs[0].maspKey).toString('hex'),
      '0x' + outputs[1].encrypt(outputs[1].maspKey).toString('hex')
    );

    const roots = await this.populateRootsForProof();

    const publicInputs = await this.publicInputsWithProof(
      roots,
      chainId,
      assetID,
      tokenID,
      inputs,
      outputs,
      dummyInMaspKey,
      feeAssetID,
      feeTokenID,
      whitelistedAssetIds,
      feeInputs,
      feeOutputs,
      dummyFeeInMaspKey,
      extAmount,
      BigNumber.from(fee),
      extDataHash,
      merkleProofs,
      feeMerkleProofs
    );

    const auxInputs = MultiAssetVAnchorBase.auxInputsToBytes(publicInputs);

    const tx = await this.contract.transact(
      '0x' + publicInputs.proof,
      auxInputs,
      {
        recipient: extData.recipient,
        extAmount: extData.extAmount,
        relayer: extData.relayer,
        fee: extData.fee,
        refund: extData.refund,
        token: extData.token,
      },
      {
        roots: MultiAssetVAnchorBase.createRootsBytes(publicInputs.roots),
        extensionRoots: '0x',
        inputNullifiers: publicInputs.inputNullifier,
        outputCommitments: [publicInputs.outputCommitment[0], publicInputs.outputCommitment[1]],
        publicAmount: publicInputs.publicAmount,
        extDataHash: publicInputs.extDataHash,
      },
      {
        encryptedOutput1: extData.encryptedOutput1,
        encryptedOutput2: extData.encryptedOutput2,
      },
      {}
    );

    const receipt = await tx.wait();
    return receipt;
  }

  // Smart contract interaction for swap
  public async swapInner(
    aliceSpendRecord: MaspUtxo,
    aliceChangeRecord: MaspUtxo,
    aliceReceiveRecord: MaspUtxo,
    bobSpendRecord: MaspUtxo,
    bobChangeRecord: MaspUtxo,
    bobReceiveRecord: MaspUtxo,
    aliceSig: any,
    bobSig: any,
    t: BigNumber,
    tPrime: BigNumber,
    currentTimestamp: BigNumber,
    commitmentTree: MerkleTree,
    signer: ethers.Signer
  ) {
    const evmId = await signer.getChainId();
    const swapChainID = getChainIdType(evmId);
    const aliceSpendMerkleProof = await MultiAssetVAnchorBase.getMASPMerkleProof(
      aliceSpendRecord,
      commitmentTree
    );
    const bobSpendMerkleProof = await MultiAssetVAnchorBase.getMASPMerkleProof(
      bobSpendRecord,
      commitmentTree
    );
    const { swapAllInputs, swapPublicInputs } = await this.generateSwapInputsWithProof(
      aliceSpendRecord,
      aliceChangeRecord,
      aliceReceiveRecord,
      bobSpendRecord,
      bobChangeRecord,
      bobReceiveRecord,
      aliceSpendMerkleProof,
      bobSpendMerkleProof,
      aliceSig,
      bobSig,
      t,
      tPrime,
      currentTimestamp,
      BigNumber.from(swapChainID)
    );
    await this.contract.swap(
      '0x' + swapPublicInputs.proof,
      {
        aliceSpendNullifier: swapPublicInputs.aliceSpendNullifier,
        bobSpendNullifier: swapPublicInputs.bobSpendNullifier,
        swapChainID: swapPublicInputs.swapChainID,
        roots: MultiAssetVAnchorBase.createRootsBytes(swapPublicInputs.roots),
        currentTimestamp: swapPublicInputs.currentTimestamp,
        aliceChangeRecord: swapPublicInputs.aliceChangeRecord,
        bobChangeRecord: swapPublicInputs.bobChangeRecord,
        aliceReceiveRecord: swapPublicInputs.aliceReceiveRecord,
        bobReceiveRecord: swapPublicInputs.bobReceiveRecord,
      },
      {
        encryptedOutput1: aliceChangeRecord.encrypt(aliceChangeRecord.maspKey),
        encryptedOutput2: aliceReceiveRecord.encrypt(aliceReceiveRecord.maspKey),
      },
      {
        encryptedOutput1: bobChangeRecord.encrypt(bobChangeRecord.maspKey),
        encryptedOutput2: bobReceiveRecord.encrypt(bobReceiveRecord.maspKey),
      }
    );
  }
}
