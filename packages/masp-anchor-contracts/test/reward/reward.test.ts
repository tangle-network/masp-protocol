/**
 * Copyright 2021-2022 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

const assert = require('assert');
const TruffleAssert = require('truffle-assertions');

const { toWei } = require('web3-utils');
const snarkjs = require('snarkjs');

import { Keypair, MerkleTree, toFixedHex, randomBN, poseidonSpongeHash } from '@webb-tools/utils';
import { BigNumber } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { poseidon } from 'circomlibjs';
import { getChainIdType, hexToU8a, ZkComponents } from '@webb-tools/utils';
import { MaspUtxo, MaspKey } from '@webb-tools/masp-anchors';
import { maspRewardFixtures } from '@webb-tools/protocol-solidity-extension-utils';
import { RewardManager, RewardProofVerifier, RewardSwap } from '@webb-tools/masp-reward';
import { DeterministicDeployFactory__factory } from '@webb-tools/contracts';
import { Deployer } from '@webb-tools/create2-utils';
import { TangleTokenMockFixedSupply__factory } from '@webb-tools/masp-anchor-contracts';
import { anonymityRewardPointsToTNT } from '@webb-tools/masp-reward';
import { PoseidonHasher } from '@webb-tools/anchors';

const maspRewardZkComponents = maspRewardFixtures('../../../solidity-fixtures/solidity-fixtures');

describe('MASP Reward Tests for maxEdges=2, levels=30', () => {
  let sender: SignerWithAddress;
  let recipient: SignerWithAddress;
  let relayer: SignerWithAddress;
  let deployer: Deployer;
  let unspentTree: MerkleTree;
  let spentTree: MerkleTree;
  // VAnchor-like contract's merkle-tree
  let maspMerkleTree: MerkleTree;
  let emptyTreeRoot: BigNumber;

  const rewardSwapMiningConfig = {
    miningCap: toWei(1000000, 'ether'),
    initialLiquidity: toWei(100000, 'ether'),
    poolWeight: 365 * 24 * 60 * 60, // 1 year
  };

  const salt = '666';
  const saltHex = ethers.utils.id(salt);

  const maxEdges = 2;
  const chainID = getChainIdType(31337);
  const anotherChainID = getChainIdType(30337);
  const levels = 30;
  const whitelistedAssetIDs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  const rates = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

  let hasherInstance;

  before('should initialize trees', async () => {
    const signers = await ethers.getSigners();
    const wallet = signers[0];
    sender = wallet;
    recipient = signers[1];
    relayer = signers[2];

    const deployerFactory = new DeterministicDeployFactory__factory(sender);
    let deployerContract = await deployerFactory.deploy();
    await deployerContract.deployed();
    deployer = new Deployer(deployerContract);

    hasherInstance = await PoseidonHasher.createPoseidonHasher(sender);

  });

  beforeEach('should reset trees', async () => {
    unspentTree = new MerkleTree(levels);
    spentTree = new MerkleTree(levels);
    maspMerkleTree = new MerkleTree(levels);
    emptyTreeRoot = maspMerkleTree.root();
  });

  describe('snarkjs local reward proof gen & verify', () => {
    let rewardCircuitZkComponents: ZkComponents;
    let create2InputWitness;

    before('should initialize zk-components', async () => {
      rewardCircuitZkComponents = await maspRewardZkComponents[230]();
      create2InputWitness = async (data: any) => {
        const wtns = await rewardCircuitZkComponents.witnessCalculator.calculateWTNSBin(data, 0);
        return wtns;
      };
    });
    it('should work for the basic flow for reward', async () => {
      const assetID = 3;
      const tokenID = 0;
      const rate = 30;

      // Create MASP Key
      const maspKey = new MaspKey();

      // Create MASP Utxo
      const maspAmount = 1;
      const maspUtxo = new MaspUtxo(
        BigNumber.from(chainID),
        maspKey,
        assetID,
        BigNumber.from(tokenID),
        BigNumber.from(maspAmount)
      );

      // create deposit UTXO
      const maspCommitment = maspUtxo.getCommitment();
      await maspMerkleTree.insert(maspCommitment);
      assert.strictEqual(maspMerkleTree.number_of_elements(), 1);
      const maspPath = maspMerkleTree.path(0);
      const maspPathIndices = MerkleTree.calculateIndexFromPathIndices(maspPath.pathIndices);
      maspUtxo.forceSetIndex(BigNumber.from(0));
      const maspNullifier = maspUtxo.getNullifier();

      // Update depositTree with vanchor UTXO commitment
      const unspentTimestamp = Date.now();
      const unspentLeaf = poseidon([maspCommitment, unspentTimestamp]);
      await unspentTree.insert(unspentLeaf);
      assert.strictEqual(unspentTree.number_of_elements(), 1);

      const spentTimestamp = Date.now() + 1000;
      const spentLeaf = poseidon([maspNullifier, spentTimestamp]);
      await spentTree.insert(spentLeaf);
      assert.strictEqual(spentTree.number_of_elements(), 1);
      const spentRoots = [spentTree.root().toString(), emptyTreeRoot.toString()];
      const spentPath = spentTree.path(0);
      const spentPathElements = spentPath.pathElements.map((bignum: BigNumber) =>
        bignum.toString()
      );
      const spentPathIndices = MerkleTree.calculateIndexFromPathIndices(spentPath.pathIndices);

      const unspentRoots = [unspentTree.root().toString(), emptyTreeRoot.toString()];
      const unspentPath = unspentTree.path(0);
      const unspentPathElements = unspentPath.pathElements.map((bignum: BigNumber) =>
        bignum.toString()
      );
      const unspentPathIndices = MerkleTree.calculateIndexFromPathIndices(unspentPath.pathIndices);

      const anonymityRewardPoints = maspAmount * rate * (spentTimestamp - unspentTimestamp);
      const rewardNullifier = poseidon([maspNullifier, maspPathIndices]);

      const extDataHash = randomBN(31);

      const publicInputDataHash = toPublicInputDataHash(
        anonymityRewardPoints,
        rewardNullifier,
        extDataHash,
        whitelistedAssetIDs,
        rates,
        spentRoots,
        unspentRoots
      );

      const circuitInput = {
        anonymityRewardPoints: anonymityRewardPoints,
        rewardNullifier: rewardNullifier,
        // Dummy
        extDataHash: extDataHash.toHexString(),
        whitelistedAssetIDs: whitelistedAssetIDs,
        rates: rates,

        // MASP Spent Note for which anonymity points are being claimed
        noteChainID: chainID,
        noteAmount: maspAmount,
        noteAssetID: assetID,
        noteTokenID: tokenID,
        note_ak_X: maspKey.getProofAuthorizingKey()[0],
        note_ak_Y: maspKey.getProofAuthorizingKey()[1],
        noteBlinding: maspUtxo.blinding,
        notePathIndices: maspPathIndices,

        unspentTimestamp: unspentTimestamp,
        unspentRoots: unspentRoots,
        unspentPathIndices: unspentPathIndices,
        unspentPathElements: unspentPathElements,

        spentTimestamp: spentTimestamp,
        spentRoots: spentRoots,
        spentPathIndices: spentPathIndices,
        spentPathElements: spentPathElements,

        publicInputDataHash: publicInputDataHash,
        selectedRewardRate: rate,
      };

      const wtns = await create2InputWitness(circuitInput);
      let res = await snarkjs.groth16.prove(rewardCircuitZkComponents.zkey, wtns);
      const vKey = await snarkjs.zKey.exportVerificationKey(rewardCircuitZkComponents.zkey);
      const verified = await snarkjs.groth16.verify(vKey, res.publicSignals, res.proof);
      assert.strictEqual(verified, true);
    });
  });

  // Test for masp reward
  describe('MASP Reward contract test', () => {

    it('should be able to claim reward', async () => {
      const assetID = 1;
      const tokenID = 0;
      const rate = 10;
      const fee = 1000;
      const delta = 10000; // max floating point error

      const tangleTokenMockFactory = new TangleTokenMockFixedSupply__factory(sender);
      const tangleTokenMockContract = await tangleTokenMockFactory.deploy();
      await tangleTokenMockContract.deployed();

      const rewardVerifier = await RewardProofVerifier.create2RewardProofVerifier(
        deployer,
        saltHex,
        sender
      );

      const rewardSwap = await RewardSwap.create2RewardSwap(
        deployer,
        sender,
        saltHex,
        sender.address,
        tangleTokenMockContract.address,
        rewardSwapMiningConfig.miningCap,
        rewardSwapMiningConfig.initialLiquidity,
        rewardSwapMiningConfig.poolWeight
      );

      // transfer TNT to rewardSwap
      tangleTokenMockContract.transfer(
        rewardSwap.contract.address,
        rewardSwapMiningConfig.miningCap
      );

      // create a new reward manager
      const rewardManager = await RewardManager.createRewardManager(
        deployer,
        sender,
        saltHex,
        rewardSwap.contract.address,
        rewardVerifier,
        sender.address,
        hasherInstance.contract.address,
        maxEdges,
        whitelistedAssetIDs,
        rates
      );
      // set manager
      rewardSwap.initialize(rewardManager.contract.address);

      // Add edges to different VAnchor Chains
      await rewardManager.addEdge(chainID);
      await rewardManager.addEdge(anotherChainID);

      // Create MASP Key
      const maspKey = new MaspKey();

      // Create MASP Utxo
      const maspAmount = 100;
      const maspUtxo = new MaspUtxo(
        BigNumber.from(chainID),
        maspKey,
        assetID,
        BigNumber.from(tokenID),
        BigNumber.from(maspAmount)
      );

      // create deposit UTXO
      const maspCommitment = maspUtxo.getCommitment();
      await maspMerkleTree.insert(maspCommitment);
      assert.strictEqual(maspMerkleTree.number_of_elements(), 1);
      const maspPath = maspMerkleTree.path(0);
      const maspPathIndices = MerkleTree.calculateIndexFromPathIndices(maspPath.pathIndices);
      maspUtxo.forceSetIndex(BigNumber.from(0));
      const maspNullifier = maspUtxo.getNullifier();

      // Update depositTree with vanchor UTXO commitment
      const unspentTimestamp = Date.now();
      const unspentLeaf = poseidon([maspCommitment, unspentTimestamp]);
      await unspentTree.insert(unspentLeaf);
      assert.strictEqual(unspentTree.number_of_elements(), 1);
      const unspentRoots = [unspentTree.root().toString(), emptyTreeRoot.toString()];
      const unspentPath = unspentTree.path(0);
      const unspentPathElements = unspentPath.pathElements.map((bignum: BigNumber) =>
        bignum.toString()
      );
      const unspentPathIndices = MerkleTree.calculateIndexFromPathIndices(unspentPath.pathIndices);
      await rewardManager.addRootToUnspentList(chainID, unspentTree.root());
      await rewardManager.addRootToUnspentList(anotherChainID, emptyTreeRoot);

      const spentTimestamp = unspentTimestamp + 10 * 24 * 60 * 60; // 10 days difference
      const spentLeaf = poseidon([maspNullifier, spentTimestamp]);
      await spentTree.insert(spentLeaf);
      assert.strictEqual(spentTree.number_of_elements(), 1);
      const spentRoots = [spentTree.root().toString(), emptyTreeRoot.toString()];
      const spentPath = spentTree.path(0);
      const spentPathElements = spentPath.pathElements.map((bignum: BigNumber) =>
        bignum.toString()
      );
      const spentPathIndices = MerkleTree.calculateIndexFromPathIndices(spentPath.pathIndices);
      await rewardManager.addRootToSpentList(chainID, spentTree.root());
      await rewardManager.addRootToSpentList(anotherChainID, emptyTreeRoot);

      const relayerTNTBalanceBefore = await tangleTokenMockContract.balanceOf(relayer.address);
      const recipientTNTBalanceBefore = await tangleTokenMockContract.balanceOf(recipient.address);

      let anonymityRewardPoints = maspAmount * rate * (spentTimestamp - unspentTimestamp);
      let expectedRecipientTNT = await rewardSwap.getExpectedTntReturn(
        BigNumber.from(anonymityRewardPoints)
      );
      let expectedRelayerFeeTNT = await rewardSwap.getExpectedTntReturn(
        BigNumber.from(anonymityRewardPoints + fee)
      );
      expectedRelayerFeeTNT = expectedRelayerFeeTNT.sub(expectedRecipientTNT);

      // reward
      await rewardManager.reward(
        maspUtxo,
        maspPathIndices,
        spentTimestamp,
        spentRoots,
        spentPathIndices,
        spentPathElements,
        unspentTimestamp,
        unspentRoots,
        unspentPathIndices,
        unspentPathElements,
        fee,
        recipient.address,
        relayer.address
      );

      const relayerTNTBalanceAfter = await tangleTokenMockContract.balanceOf(relayer.address);
      const recipientTNTBalanceAfter = await tangleTokenMockContract.balanceOf(recipient.address);

      assert(
        relayerTNTBalanceAfter
          .sub(relayerTNTBalanceBefore)
          .sub(expectedRelayerFeeTNT)
          .lt(BigNumber.from(delta))
      );
      // to make following work, we need #TODO implement a function to reset blocktime
      // assert(recipientTNTBalanceAfter.sub(recipientTNTBalanceBefore).eq(expectedRecipientTNT));
    });

    it('should reject reclaim(double spend) of reward', async () => {
      const assetID = 1;
      const tokenID = 0;
      const fee = 1000;

      const tangleTokenMockFactory = new TangleTokenMockFixedSupply__factory(sender);
      const tangleTokenMockContract = await tangleTokenMockFactory.deploy();
      await tangleTokenMockContract.deployed();

      const rewardVerifier = await RewardProofVerifier.create2RewardProofVerifier(
        deployer,
        saltHex,
        sender
      );

      const rewardSwap = await RewardSwap.create2RewardSwap(
        deployer,
        sender,
        saltHex,
        sender.address,
        tangleTokenMockContract.address,
        rewardSwapMiningConfig.miningCap,
        rewardSwapMiningConfig.initialLiquidity,
        rewardSwapMiningConfig.poolWeight
      );

      // transfer TNT to rewardSwap
      tangleTokenMockContract.transfer(
        rewardSwap.contract.address,
        rewardSwapMiningConfig.miningCap
      );

      // create a new reward manager
      const rewardManager = await RewardManager.createRewardManager(
        deployer,
        sender,
        saltHex,
        rewardSwap.contract.address,
        rewardVerifier,
        sender.address,
        hasherInstance.contract.address,
        maxEdges,
        whitelistedAssetIDs,
        rates
      );
      // set manager
      rewardSwap.initialize(rewardManager.contract.address);

      // Add edges to different VAnchor Chains
      await rewardManager.addEdge(chainID);
      await rewardManager.addEdge(anotherChainID);

      // Create MASP Key
      const maspKey = new MaspKey();

      // Create MASP Utxo
      const maspAmount = 100;
      const maspUtxo = new MaspUtxo(
        BigNumber.from(chainID),
        maspKey,
        assetID,
        BigNumber.from(tokenID),
        BigNumber.from(maspAmount)
      );

      // create deposit UTXO
      const maspCommitment = maspUtxo.getCommitment();
      await maspMerkleTree.insert(maspCommitment);
      assert.strictEqual(maspMerkleTree.number_of_elements(), 1);
      const maspPath = maspMerkleTree.path(0);
      const maspPathIndices = MerkleTree.calculateIndexFromPathIndices(maspPath.pathIndices);
      maspUtxo.forceSetIndex(BigNumber.from(0));
      const maspNullifier = maspUtxo.getNullifier();

      // Update depositTree with vanchor UTXO commitment
      const unspentTimestamp = Date.now();
      const unspentLeaf = poseidon([maspCommitment, unspentTimestamp]);
      await unspentTree.insert(unspentLeaf);
      assert.strictEqual(unspentTree.number_of_elements(), 1);
      const unspentRoots = [unspentTree.root().toString(), emptyTreeRoot.toString()];
      const unspentPath = unspentTree.path(0);
      const unspentPathElements = unspentPath.pathElements.map((bignum: BigNumber) =>
        bignum.toString()
      );
      const unspentPathIndices = MerkleTree.calculateIndexFromPathIndices(unspentPath.pathIndices);
      await rewardManager.addRootToUnspentList(chainID, unspentTree.root());
      await rewardManager.addRootToUnspentList(anotherChainID, emptyTreeRoot);

      const spentTimestamp = unspentTimestamp + 10 * 60 * 24; // 10 days difference
      const spentLeaf = poseidon([maspNullifier, spentTimestamp]);
      await spentTree.insert(spentLeaf);
      assert.strictEqual(spentTree.number_of_elements(), 1);
      const spentRoots = [spentTree.root().toString(), emptyTreeRoot.toString()];
      const spentPath = spentTree.path(0);
      const spentPathElements = spentPath.pathElements.map((bignum: BigNumber) =>
        bignum.toString()
      );
      const spentPathIndices = MerkleTree.calculateIndexFromPathIndices(spentPath.pathIndices);
      await rewardManager.addRootToSpentList(chainID, spentTree.root());
      await rewardManager.addRootToSpentList(anotherChainID, emptyTreeRoot);

      // reward
      await rewardManager.reward(
        maspUtxo,
        maspPathIndices,
        spentTimestamp,
        spentRoots,
        spentPathIndices,
        spentPathElements,
        unspentTimestamp,
        unspentRoots,
        unspentPathIndices,
        unspentPathElements,
        fee,
        recipient.address,
        relayer.address
      );

      // reclaim reward, this is rejected because rewrdNullifier is already claimed
      await TruffleAssert.reverts(
        rewardManager.reward(
          maspUtxo,
          maspPathIndices,
          spentTimestamp,
          spentRoots,
          spentPathIndices,
          spentPathElements,
          unspentTimestamp,
          unspentRoots,
          unspentPathIndices,
          unspentPathElements,
          fee,
          recipient.address,
          relayer.address
        ),
        'Reward has been already spent'
      );
    });
  });
});

// Helper function to hash `IMASPRewardExtData` to a field element
function toPublicInputDataHash(
  anonymityRewardPoints: number,
  rewardNullifier: BigNumber,
  extDataHash: BigNumber,
  whitelistedAssetIDs: number[],
  rates: number[],
  spentRoots: string[],
  unspentRoots: string[],
): BigNumber {
  const whitelistedAssetIDsBN = whitelistedAssetIDs.map(num => BigNumber.from(num));
  const ratesBN = rates.map(num => BigNumber.from(num));
  const spentRootsBN = spentRoots.map(num => BigNumber.from(num));
  const unspentRootsBN = unspentRoots.map(num => BigNumber.from(num));
  const inputs = whitelistedAssetIDsBN.concat(ratesBN, spentRootsBN, unspentRootsBN, BigNumber.from(anonymityRewardPoints), rewardNullifier, extDataHash);
  return poseidonSpongeHash(inputs);
}
