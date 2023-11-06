import { BigNumber, BigNumberish, ContractReceipt, ethers } from 'ethers';
const assert = require('assert');
const snarkjs = require('snarkjs');
import { poseidon } from 'circomlibjs';
import {
  RewardManager as RewardManagerContract,
  RewardManager__factory,
  RewardEncodeInputs__factory,
} from '@webb-tools/masp-anchor-contracts';
import { maspRewardFixtures } from '@webb-tools/protocol-solidity-extension-utils';
import { getChainIdType, ZkComponents, toFixedHex, FIELD_SIZE } from '@webb-tools/utils';
import { Deployer } from '@webb-tools/create2-utils';
import { MaspUtxo } from '@webb-tools/masp-anchors';
import { IMASPRewardExtData, IMASPRewardAllInputs } from './interfaces';
import RewardProofVerifier from './RewardVerifier';
import { poseidonSpongeHash } from '@webb-tools/utils';

const maspRewardZkComponents = maspRewardFixtures('../../../solidity-fixtures/solidity-fixtures');

export class RewardManager {
  contract: RewardManagerContract;
  signer: ethers.Signer;
  zkComponents: ZkComponents;
  maxEdges: number;
  whitelistedAssetIDs: number[];
  rates: number[];

  // Constructor
  public constructor(
    contract: RewardManagerContract,
    signer: ethers.Signer,
    zkComponents: ZkComponents,
    maxEdges: number,
    whitelistedAssetIDs: number[],
    rates: number[]
  ) {
    this.contract = contract;
    this.signer = signer;
    this.zkComponents = zkComponents;
    this.maxEdges = maxEdges;
    this.whitelistedAssetIDs = whitelistedAssetIDs;
    this.rates = rates;
  }

  // Deploy a new RewardManager
  public static async createRewardManager(
    deployer: Deployer,
    signer: ethers.Signer,
    saltHex: string,
    rewardSwapContractAddr: string,
    rewardVerifierContract: RewardProofVerifier,
    governanceAddr: string,
    hasherAddr: string,
    maxEdges: number,
    initialWhitelistedAssetIds: number[],
    rates: number[]
  ) {
    let zkComponents: ZkComponents;

    if (maxEdges == 2) {
      zkComponents = await maspRewardZkComponents[230]();
    } else if (maxEdges == 8) {
      zkComponents = await maspRewardZkComponents[830]();
    } else {
      throw new Error('maxEdges must be 2 or 8');
    }
    if (initialWhitelistedAssetIds.length != rates.length) {
      throw new Error('whitelisted-asset-id list length must be equal to rate-list id length');
    }

    const { contract: rewardEncodeLibrary } = await deployer.deploy(
      RewardEncodeInputs__factory,
      saltHex,
      signer
    );
    const libraryAddresses = {
      ['contracts/reward/RewardEncodeInputs.sol:RewardEncodeInputs']: rewardEncodeLibrary.address,
    };

    const factory = new RewardManager__factory(libraryAddresses, signer);
    const manager = await factory.deploy(
      rewardSwapContractAddr,
      rewardVerifierContract.contract.address,
      governanceAddr,
      hasherAddr,
      maxEdges,
      initialWhitelistedAssetIds,
      rates
    );
    await manager.deployed();

    return new RewardManager(
      manager,
      signer,
      zkComponents,
      maxEdges,
      initialWhitelistedAssetIds,
      rates
    );
  }

  // Deploy a new RewardManager using CREATE2
  // #TODO does not work yet, whitelistedAssetIds is not getting set correctly in RewardManager contract
  public static async create2RewardManager(
    deployer: Deployer,
    signer: ethers.Signer,
    saltHex: string,
    rewardSwapContractAddr: string,
    rewardVerifierContract: RewardProofVerifier,
    governanceAddr: string,
    hasherAddr: string,
    maxEdges: number,
    initialWhitelistedAssetIds: number[],
    rates: number[]
  ) {
    let zkComponents: ZkComponents;

    if (maxEdges == 2) {
      zkComponents = await maspRewardZkComponents[230]();
    } else if (maxEdges == 8) {
      zkComponents = await maspRewardZkComponents[830]();
    } else {
      throw new Error('maxEdges must be 2 or 8');
    }
    if (initialWhitelistedAssetIds.length != rates.length) {
      throw new Error('whitelisted-asset-id list length must be equal to rate-list id length');
    }

    const argTypes = ['address', 'address', 'address', 'address', 'uint8', 'uint32[]', 'uint32[]'];
    const args = [
      rewardSwapContractAddr,
      rewardVerifierContract.contract.address,
      governanceAddr,
      hasherAddr,
      maxEdges,
      initialWhitelistedAssetIds,
      rates,
    ];

    const { contract: rewardEncodeLibrary } = await deployer.deploy(
      RewardEncodeInputs__factory,
      saltHex,
      signer
    );
    const libraryAddresses = {
      ['contracts/reward/RewardEncodeInputs.sol:RewardEncodeInputs']: rewardEncodeLibrary.address,
    };
    const { contract: manager } = await deployer.deploy(
      RewardManager__factory,
      saltHex,
      signer,
      libraryAddresses,
      argTypes,
      args
    );

    return new RewardManager(
      manager,
      signer,
      zkComponents,
      maxEdges,
      initialWhitelistedAssetIds,
      rates
    );
  }

  // Set the rate (only callable by the governance)
  public async setRate(newRates: number[]): Promise<void> {
    const tx = await this.contract.setRates(newRates);
    await tx.wait();
  }

  // Set the pool weight (only callable by the governance)
  public async setPoolWeight(newWeight: BigNumber): Promise<void> {
    const tx = await this.contract.setPoolWeight(newWeight);
    await tx.wait();
  }

  // Update the whitelistedAssetIds (only callable by the governance)
  public async setWhiteListedAssetIds(newAssetIds: number[]): Promise<void> {
    const tx = await this.contract.setWhitelistedAssetIDs(newAssetIds);
    await tx.wait();
  }

  // Get the latest spent roots
  public async getLatestSpentRoots(): Promise<BigNumber[]> {
    return await this.contract.getLatestSpentRoots();
  }

  // Get the latest unspent roots
  public async getLatestUnspentRoots(): Promise<BigNumber[]> {
    return await this.contract.getLatestUnspentRoots();
  }

  // Add a new edge (only callable by the governance)
  public async addEdge(chainId: number): Promise<void> {
    const tx = await this.contract.addEdge(chainId);
    await tx.wait();
  }

  // Add a root to the spent list of an existing edge (only callable by the governance)
  public async addRootToSpentList(chainId: number, root: BigNumber): Promise<void> {
    const tx = await this.contract.addRootToSpentList(chainId, root);
    await tx.wait();
  }

  // Add a root to the unspent list of an existing edge (only callable by the governance)
  public async addRootToUnspentList(chainId: number, root: BigNumber): Promise<void> {
    const tx = await this.contract.addRootToUnspentList(chainId, root);
    await tx.wait();
  }

  // Generate a reward proof
  public async generateRewardProof(rewardAllInputs: IMASPRewardAllInputs): Promise<any> {
    const wtns = await this.zkComponents.witnessCalculator.calculateWTNSBin(rewardAllInputs, 0);
    let res = await snarkjs.groth16.prove(this.zkComponents.zkey, wtns);
    const vKey = await snarkjs.zKey.exportVerificationKey(this.zkComponents.zkey);
    const verified = await snarkjs.groth16.verify(vKey, res.publicSignals, res.proof);
    assert.strictEqual(verified, true);

    // Generate encoded reward proof
    const calldata = await snarkjs.groth16.exportSolidityCallData(res.proof, res.publicSignals);
    const proofJson = JSON.parse('[' + calldata + ']');
    const pi_a = proofJson[0];
    const pi_b = proofJson[1];
    const pi_c = proofJson[2];

    let proofEncoded = [
      pi_a[0],
      pi_a[1],
      pi_b[0][0],
      pi_b[0][1],
      pi_b[1][0],
      pi_b[1][1],
      pi_c[0],
      pi_c[1],
    ]
      .map((elt) => elt.substr(2))
      .join('');

    proofEncoded = `0x${proofEncoded}`;
    return { proofEncoded: proofEncoded, publicSignals: res.publicSignals };
  }

  // Helper function to hash `IMASPRewardExtData` to a field element
  public toRewardExtDataHash(extData: IMASPRewardExtData): BigNumber {
    const abi = new ethers.utils.AbiCoder();
    const encodedData = abi.encode(
      ['uint256', 'address', 'address'],
      [extData.fee, extData.recipient, extData.relayer]
    );

    const hash = ethers.utils.keccak256(encodedData);
    return BigNumber.from(hash).mod(FIELD_SIZE);
  }

  // Helper function to compte rewardNullifier
  public computeRewardNullifier(
    maspNoteNullifier: BigNumber,
    maspNotePathIndices: number
  ): BigNumber {
    return poseidon([maspNoteNullifier, maspNotePathIndices]);
  }

  // Helper function to hash `IMASPRewardExtData` to a field element
  public toPublicInputDataHash(
    anonymityRewardPoints: BigNumber,
    rewardNullifier: BigNumber,
    extDataHash: BigNumber,
    spentRoots: BigNumber[],
    unspentRoots: BigNumber[]
  ): BigNumber {
    const whitelistedAssetIDs = this.whitelistedAssetIDs.map((num) => BigNumber.from(num));
    const rates = this.rates.map((num) => BigNumber.from(num));
    const inputs = whitelistedAssetIDs.concat(
      rates,
      spentRoots,
      unspentRoots,
      anonymityRewardPoints,
      rewardNullifier,
      extDataHash
    );
    return poseidonSpongeHash(inputs);
  }

  // Generate MASP Reward Inputs
  public generateMASPRewardInputs(
    maspNote: MaspUtxo,
    maspNotePathIndices: number,
    rewardNullifier: BigNumber,
    spentTimestamp: EpochTimeStamp,
    spentRoots: BigNumberish[],
    spentPathIndices: BigNumberish,
    spentPathElements: BigNumberish[],
    unspentTimestamp: EpochTimeStamp,
    unspentRoots: BigNumberish[],
    unspentPathIndices: BigNumberish,
    unspentPathElements: BigNumberish[],
    extData: IMASPRewardExtData
  ): IMASPRewardAllInputs {
    const selectedRewardRate = this.getRate(maspNote.assetID);
    const anonymityRewardPoints = maspNote.amount
      .mul(selectedRewardRate)
      .mul(spentTimestamp - unspentTimestamp);
    const extDataHash = this.toRewardExtDataHash(extData);
    const spentRootsBigNumber = spentRoots.map((num) => BigNumber.from(num));
    const unspentRootsBigNumber = unspentRoots.map((num) => BigNumber.from(num));
    const publicInputDataHash = this.toPublicInputDataHash(
      anonymityRewardPoints,
      rewardNullifier,
      extDataHash,
      spentRootsBigNumber,
      unspentRootsBigNumber
    );

    return {
      anonymityRewardPoints: anonymityRewardPoints,
      rewardNullifier: rewardNullifier,
      extDataHash: extDataHash,
      whitelistedAssetIDs: this.whitelistedAssetIDs,
      rates: this.rates,
      noteChainID: maspNote.chainID,
      noteAmount: maspNote.amount,
      noteAssetID: maspNote.assetID,
      noteTokenID: maspNote.tokenID,
      note_ak_X: maspNote.maspKey.getProofAuthorizingKey()[0],
      note_ak_Y: maspNote.maspKey.getProofAuthorizingKey()[1],
      noteBlinding: maspNote.blinding,
      notePathIndices: maspNotePathIndices,
      spentTimestamp: spentTimestamp,
      spentRoots: spentRoots,
      spentPathIndices: spentPathIndices,
      spentPathElements: spentPathElements,
      unspentTimestamp: unspentTimestamp,
      unspentRoots: unspentRoots,
      unspentPathIndices: unspentPathIndices,
      unspentPathElements: unspentPathElements,
      selectedRewardRate: selectedRewardRate,
      publicInputDataHash: publicInputDataHash,
    };
  }

  // This function is called by the relayer to claim the reward.
  // The relayer will receive the reward amount and the fee.
  // The recipient will receive the remaining amount.
  public async reward(
    maspNote: MaspUtxo,
    maspNotePathIndices: number,
    spentTimestamp: EpochTimeStamp,
    spentRoots: BigNumberish[],
    spentPathIndices: BigNumberish,
    spentPathElements: BigNumberish[],
    unspentTimestamp: EpochTimeStamp,
    unspentRoots: BigNumberish[],
    unspentPathIndices: BigNumberish,
    unspentPathElements: BigNumberish[],
    fee: BigNumberish,
    recipient: string,
    relayer: string
  ): Promise<{ anonymityRewardPoints: BigNumberish; receipt: ContractReceipt }> {
    const extData: IMASPRewardExtData = {
      fee: fee,
      recipient: recipient,
      relayer: relayer,
    };

    const rewardNullifier = this.computeRewardNullifier(
      maspNote.getNullifier(),
      maspNotePathIndices
    );

    const rewardAllInputs = this.generateMASPRewardInputs(
      maspNote,
      maspNotePathIndices,
      rewardNullifier,
      spentTimestamp,
      spentRoots,
      spentPathIndices,
      spentPathElements,
      unspentTimestamp,
      unspentRoots,
      unspentPathIndices,
      unspentPathElements,
      extData
    );

    const { proofEncoded, publicSignals } = await this.generateRewardProof(rewardAllInputs);

    const tx = await this.contract.reward(
      proofEncoded,
      {
        anonymityRewardPoints: rewardAllInputs.anonymityRewardPoints,
        rewardNullifier: rewardAllInputs.rewardNullifier,
        extDataHash: rewardAllInputs.extDataHash,
        whitelistedAssetIDs: RewardManager.createBNArrayToBytes(this.whitelistedAssetIDs),
        rates: RewardManager.createBNArrayToBytes(this.rates),
        spentRoots: RewardManager.createBNArrayToBytes(spentRoots),
        unspentRoots: RewardManager.createBNArrayToBytes(unspentRoots),
        publicInputDataHash: publicSignals[0],
      },
      extData
    );
    const receipt = await tx.wait();
    const anonymityRewardPoints = rewardAllInputs.anonymityRewardPoints;
    return { anonymityRewardPoints, receipt };
  }

  // Get the reward rate for a given asset-id
  public getRate(assetId: number): number {
    let assetIdIndex = 0;
    let found = false;
    for (let i = 0; i < this.whitelistedAssetIDs.length; i++) {
      if (assetId == this.whitelistedAssetIDs[i]) {
        found = true;
        assetIdIndex = i;
      }
    }
    if (found) {
      return this.rates[assetIdIndex];
    } else {
      throw new Error('asset-id doesnot exist');
    }
  }

  public static createBNArrayToBytes(arr: BigNumberish[]) {
    let result = '0x';
    for (let i = 0; i < arr.length; i++) {
      result += toFixedHex(arr[i]).substr(2);
    }
    return result; // root byte string (32 * array.length bytes)
  }
}
