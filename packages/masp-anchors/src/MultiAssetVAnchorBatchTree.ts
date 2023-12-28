import { MultiAssetVAnchor } from './MultiAssetVAnchor';
import {
  MultiAssetVAnchorBatchTree as MultiAssetVAnchorBatchTreeContract,
  MultiAssetVAnchorBatchTree__factory,
  SwapEncodeInputs__factory,
  MASPVAnchorEncodeInputs__factory,
} from '@webb-tools/masp-anchor-contracts';
import { ProxiedBatchTree } from './ProxiedBatchTree';
import { MerkleTree, ZkComponents } from '@webb-tools/utils';
import { BigNumber, BigNumberish, ethers } from 'ethers';
import { MaspUtxo } from './primitives/MaspUtxo';
import { Deployer } from '@webb-tools/create2-utils';

export class MultiAssetVAnchorBatchTree extends MultiAssetVAnchor {
  depositTree: ProxiedBatchTree;
  unspentTree: ProxiedBatchTree;
  spentTree: ProxiedBatchTree;

  // Constructor
  constructor(
    contract: MultiAssetVAnchorBatchTreeContract,
    unspentTree: ProxiedBatchTree,
    spentTree: ProxiedBatchTree,
    levels: number,
    maxEdges: number,
    smallCircuitZkComponents: ZkComponents,
    largeCircuitZkComponents: ZkComponents,
    swapCircuitZkComponents: ZkComponents,
    signer: ethers.Signer
  ) {
    super(
      contract,
      levels,
      maxEdges,
      smallCircuitZkComponents,
      largeCircuitZkComponents,
      swapCircuitZkComponents,
      signer
    );

    this.depositTree = new ProxiedBatchTree(
      null,
      signer,
      levels,
      unspentTree.zkComponents_4,
      unspentTree.zkComponents_8,
      unspentTree.zkComponents_16,
      unspentTree.zkComponents_32
    );
    this.unspentTree = unspentTree;
    this.spentTree = spentTree;
  }

  public static async create2MultiAssetVAnchorBatchTree(
    deployer: Deployer,
    saltHex: string,
    registry: string,
    transactVerifierAddr: string,
    batchVerifierAddr: string,
    swapVerifierAddr: string,
    handlerAddr: string,
    hasherAddr: string,
    proxyAddr: string,
    levels: number,
    maxEdges: number,
    smallCircuitZkComponents: ZkComponents,
    largeCircuitZkComponents: ZkComponents,
    swapCircuitZkComponents: ZkComponents,
    unspentTree: ProxiedBatchTree,
    spentTree: ProxiedBatchTree,
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

    const argTypes = [
      'address',
      'address',
      'address',
      'address',
      'address',
      'address',
      'address',
      'address',
      'address',
      'uint8',
      'uint8',
    ];
    const args = [
      registry,
      transactVerifierAddr,
      swapVerifierAddr,
      batchVerifierAddr,
      handlerAddr,
      hasherAddr,
      proxyAddr,
      unspentTree.contract.address,
      spentTree.contract.address,
      levels,
      maxEdges,
    ];

    const { contract: maspVAnchorBatchTree, receipt } = await deployer.deploy(
      MultiAssetVAnchorBatchTree__factory,
      saltHex,
      signer,
      libraryAddresses,
      argTypes,
      args
    );

    const createdMASPVAnchorBatchTree = new MultiAssetVAnchorBatchTree(
      maspVAnchorBatchTree,
      unspentTree,
      spentTree,
      levels,
      maxEdges,
      smallCircuitZkComponents,
      largeCircuitZkComponents,
      swapCircuitZkComponents,
      signer
    );
    createdMASPVAnchorBatchTree.latestSyncedBlock = receipt.blockNumber!;
    const tx = await createdMASPVAnchorBatchTree.contract.initialize(
      BigNumber.from('1'),
      BigNumber.from(2).pow(256).sub(1)
    );
    await tx.wait();

    return createdMASPVAnchorBatchTree;
  }

  // Create a new MultiAssetVAnchorBatchUpdatableTree
  public static async createMultiAssetVAnchorBatchTree(
    registry: string,
    transactVerifierAddr: string,
    batchVerifierAddr: string,
    swapVerifierAddr: string,
    handlerAddr: string,
    hasherAddr: string,
    proxyAddr: string,
    levels: number,
    maxEdges: number,
    smallCircuitZkComponents: ZkComponents,
    largeCircuitZkComponents: ZkComponents,
    swapCircuitZkComponents: ZkComponents,
    zkComponents_4: ZkComponents,
    zkComponents_8: ZkComponents,
    zkComponents_16: ZkComponents,
    zkComponents_32: ZkComponents,
    signer: ethers.Signer
  ) {
    const encodeLibraryFactory = new MASPVAnchorEncodeInputs__factory(signer);
    const encodeLibrary = await encodeLibraryFactory.deploy();
    await encodeLibrary.deployed();

    const swapEncodeLibraryFactory = new SwapEncodeInputs__factory(signer);
    const swapEncodeLibrary = await swapEncodeLibraryFactory.deploy();
    await swapEncodeLibrary.deployed();

    const factory = new MultiAssetVAnchorBatchTree__factory(
      {
        ['contracts/MASPVAnchorEncodeInputs.sol:MASPVAnchorEncodeInputs']: encodeLibrary.address,
        ['contracts/SwapEncodeInputs.sol:SwapEncodeInputs']: swapEncodeLibrary.address,
      },
      signer
    );

    const unspentTree = await ProxiedBatchTree.createProxiedBatchTree(
      batchVerifierAddr,
      levels,
      hasherAddr,
      proxyAddr,
      zkComponents_4,
      zkComponents_8,
      zkComponents_16,
      zkComponents_32,
      signer
    );
    const spentTree = await ProxiedBatchTree.createProxiedBatchTree(
      batchVerifierAddr,
      levels,
      hasherAddr,
      proxyAddr,
      zkComponents_4,
      zkComponents_8,
      zkComponents_16,
      zkComponents_32,
      signer
    );
    const proxy = proxyAddr;

    const maspVAnchorBatchTree = await factory.deploy(
      registry,
      transactVerifierAddr,
      swapVerifierAddr,
      batchVerifierAddr,
      handlerAddr,
      hasherAddr,
      proxy,
      unspentTree.contract.address,
      spentTree.contract.address,
      levels,
      maxEdges
    );
    await maspVAnchorBatchTree.deployed();
    const createdMASPVAnchorBatchTree = new MultiAssetVAnchorBatchTree(
      maspVAnchorBatchTree,
      unspentTree,
      spentTree,
      levels,
      maxEdges,
      smallCircuitZkComponents,
      largeCircuitZkComponents,
      swapCircuitZkComponents,
      signer
    );
    const tx = await createdMASPVAnchorBatchTree.contract.initialize(
      BigNumber.from('1'),
      BigNumber.from(2).pow(256).sub(1)
    );
    await tx.wait();
    return createdMASPVAnchorBatchTree;
  }

  // Connect to an existing MultiAssetVAnchorBatchUpdatableTree
  public static async connect(
    // connect via factory method
    // build up tree by querying provider for logs
    maspAddress: string,
    depositTreeAddr: string,
    unspentTreeAddr: string,
    spentTreeAddr: string,
    smallCircuitZkComponents: ZkComponents,
    largeCircuitZkComponents: ZkComponents,
    swapCircuitZkComponents: ZkComponents,
    zkComponents_4: ZkComponents,
    zkComponents_8: ZkComponents,
    zkComponents_16: ZkComponents,
    zkComponents_32: ZkComponents,
    signer: ethers.Signer
  ) {
    const masp = MultiAssetVAnchorBatchTree__factory.connect(maspAddress, signer);
    const depositTree = await ProxiedBatchTree.connect(
      depositTreeAddr,
      zkComponents_4,
      zkComponents_8,
      zkComponents_16,
      zkComponents_32,
      signer
    );
    const unspentTree = await ProxiedBatchTree.connect(
      unspentTreeAddr,
      zkComponents_4,
      zkComponents_8,
      zkComponents_16,
      zkComponents_32,
      signer
    );
    const spentTree = await ProxiedBatchTree.connect(
      spentTreeAddr,
      zkComponents_4,
      zkComponents_8,
      zkComponents_16,
      zkComponents_32,
      signer
    );
    const maxEdges = await masp.maxEdges();
    const treeHeight = await masp.levels();
    const createdAnchor = new MultiAssetVAnchorBatchTree(
      masp,
      unspentTree,
      spentTree,
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
    validFeeAssetIDs: BigNumberish[],
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
      validFeeAssetIDs,
      refund,
      recipient,
      relayer,
      this.depositTree.tree,
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
      this.depositTree.tree,
      signer
    );
  }
}
