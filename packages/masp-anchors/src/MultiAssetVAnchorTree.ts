import { MultiAssetVAnchor } from './MultiAssetVAnchor';
import {
  MultiAssetVAnchorTree__factory,
  SwapEncodeInputs__factory,
  MASPVAnchorEncodeInputs__factory,
} from '@webb-tools/masp-anchor-contracts';
import { ZkComponents } from '@webb-tools/utils';
import { BigNumber, BigNumberish, ethers } from 'ethers';
import { MaspUtxo } from './primitives/MaspUtxo';
import { Deployer } from '@webb-tools/create2-utils';

export class MultiAssetVAnchorTree extends MultiAssetVAnchor {
  public static async create2MultiAssetVAnchorTree(
    deployer: Deployer,
    saltHex: string,
    registry: string,
    transactVerifierAddr: string,
    swapVerifierAddr: string,
    handlerAddr: string,
    hasherAddr: string,
    proxyAddr: string,
    levels: number,
    maxEdges: number,
    smallCircuitZkComponents: ZkComponents,
    largeCircuitZkComponents: ZkComponents,
    swapCircuitZkComponents: ZkComponents,
    signer: ethers.Signer
  ) {
    const { contract: encodeLibrary } = await deployer.deploy(
      MASPVAnchorEncodeInputs__factory,
      saltHex,
      signer
    );

    const { contract: swapEncodeLibrary } = await deployer.deploy(
      SwapEncodeInputs__factory,
      saltHex,
      signer
    );

    let libraryAddresses = {
      ['contracts/MASPVAnchorEncodeInputs.sol:MASPVAnchorEncodeInputs']: encodeLibrary.address,
      ['contracts/SwapEncodeInputs.sol:SwapEncodeInputs']: swapEncodeLibrary.address,
    };

    const proxy = proxyAddr;

    const argTypes = [
      'address',
      'address',
      'address',
      'address',
      'uint8',
      'address',
      'address',
      'uint8',
    ];
    const args = [
      registry,
      transactVerifierAddr,
      swapVerifierAddr,
      proxy,
      levels,
      hasherAddr,
      handlerAddr,
      maxEdges,
    ];

    const { contract: maspVAnchorTree, receipt } = await deployer.deploy(
      MultiAssetVAnchorTree__factory,
      saltHex,
      signer,
      libraryAddresses,
      argTypes,
      args
    );

    const createdMASPVAnchorTree = new MultiAssetVAnchorTree(
      maspVAnchorTree,
      levels,
      maxEdges,
      smallCircuitZkComponents,
      largeCircuitZkComponents,
      swapCircuitZkComponents,
      signer
    );
    createdMASPVAnchorTree.latestSyncedBlock = receipt.blockNumber!;
    const tx = await createdMASPVAnchorTree.contract.initialize(
      BigNumber.from('1'),
      BigNumber.from(2).pow(256).sub(1)
    );
    await tx.wait();

    return createdMASPVAnchorTree;
  }

  public static async createMultiAssetVAnchorTree(
    registry: string,
    transactVerifierAddr: string,
    swapVerifierAddr: string,
    handlerAddr: string,
    hasherAddr: string,
    proxyAddr: string,
    levels: number,
    maxEdges: number,
    smallCircuitZkComponents: ZkComponents,
    largeCircuitZkComponents: ZkComponents,
    swapCircuitZkComponents: ZkComponents,
    signer: ethers.Signer
  ) {
    const encodeLibraryFactory = new MASPVAnchorEncodeInputs__factory(signer);
    const encodeLibrary = await encodeLibraryFactory.deploy();
    await encodeLibrary.deployed();

    const swapEncodeLibraryFactory = new SwapEncodeInputs__factory(signer);
    const swapEncodeLibrary = await swapEncodeLibraryFactory.deploy();
    await swapEncodeLibrary.deployed();

    const factory = new MultiAssetVAnchorTree__factory(
      {
        ['contracts/MASPVAnchorEncodeInputs.sol:MASPVAnchorEncodeInputs']: encodeLibrary.address,
        ['contracts/SwapEncodeInputs.sol:SwapEncodeInputs']: swapEncodeLibrary.address,
      },
      signer
    );

    const proxy = proxyAddr;

    const maspVAnchorTree = await factory.deploy(
      registry,
      proxy,
      transactVerifierAddr,
      swapVerifierAddr,
      levels,
      hasherAddr,
      handlerAddr,
      maxEdges,
      {}
    );
    await maspVAnchorTree.deployed();
    const createdMASPVAnchorTree = new MultiAssetVAnchorTree(
      maspVAnchorTree,
      levels,
      maxEdges,
      smallCircuitZkComponents,
      largeCircuitZkComponents,
      swapCircuitZkComponents,
      signer
    );
    const tx = await createdMASPVAnchorTree.contract.initialize(
      BigNumber.from('1'),
      BigNumber.from(2).pow(256).sub(1)
    );
    await tx.wait();
    return createdMASPVAnchorTree;
  }

  // Connect to an existing MultiAssetVAnchorBatchUpdatableTree
  public static async connect(
    maspAddress: string,
    smallCircuitZkComponents: ZkComponents,
    largeCircuitZkComponents: ZkComponents,
    swapCircuitZkComponents: ZkComponents,
    signer: ethers.Signer
  ) {
    const masp = MultiAssetVAnchorTree__factory.connect(maspAddress, signer);
    const maxEdges = await masp.maxEdges();
    const treeHeight = await masp.levels();
    const createdAnchor = new MultiAssetVAnchorTree(
      masp,
      treeHeight,
      maxEdges,
      smallCircuitZkComponents,
      largeCircuitZkComponents,
      swapCircuitZkComponents,
      signer
    );
    return createdAnchor;
  }

  public async transact(
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
    signer: ethers.Signer
  ): Promise<ethers.ContractReceipt> {
    return this.transactInner(
      assetID,
      tokenID,
      wrapUnwrapToken,
      inputs,
      outputs,
      fee,
      feeAssetID,
      feeTokenID,
      feeInputs,
      feeOutputs,
      whitelistedAssetIds,
      refund,
      recipient,
      relayer,
      this.tree,
      signer
    );
  }

  // Smart contract interaction for swap
  public async swap(
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
    signer: ethers.Signer
  ) {
    return this.swapInner(
      aliceSpendRecord,
      aliceChangeRecord,
      aliceReceiveRecord,
      bobSpendRecord,
      bobChangeRecord,
      bobReceiveRecord,
      aliceSig,
      bobSig,
      t,
      tPrime,
      currentTimestamp,
      this.tree,
      signer
    );
  }
}
