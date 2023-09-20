import { BigNumber, BigNumberish, ContractReceipt, ethers } from 'ethers';
const assert = require('assert');
const snarkjs = require('snarkjs');
import { poseidon } from 'circomlibjs';
import {
    RewardManager as RewardManagerContract,
    RewardManager__factory,
    RewardEncodeInputs__factory
} from '@webb-tools/masp-anchor-contracts';
import { getChainIdType, ZkComponents, toFixedHex, FIELD_SIZE } from '@webb-tools/utils';
import { Deployer } from '@webb-tools/create2-utils';
import { MaspUtxo } from '@webb-tools/masp-anchors';

import { IMASPRewardAllInputs } from './interfaces';
import RewardProofVerifier from './RewardVerifier';

export class RewardManager {
    contract: RewardManagerContract;
    signer: ethers.Signer;
    zkComponents: ZkComponents;
    maxEdges: number;

    // Constructor
    public constructor(contract: RewardManagerContract, signer: ethers.Signer, zkComponents: ZkComponents, maxEdges: number
    ) {
        this.contract = contract;
        this.signer = signer;
        this.zkComponents = zkComponents;
        this.maxEdges = maxEdges;
    }

    // Deploy a new RewardManager
    public static async create2RewardManager(
        deployer: Deployer,
        signer: ethers.Signer,
        saltHex: string,
        rewardSwapContractAddr: string,
        rewardVerifierContract: RewardProofVerifier,
        governanceAddr: string,
        zkComponents: ZkComponents,
        maxEdges: number,
        rate: number,
        initialWhitelistedAssetIds: number[]
    ) {
        const argTypes = ['address', 'address', 'address', 'uint256', 'uint256', 'uint256[]'];
        const args = [rewardSwapContractAddr, rewardVerifierContract.contract.address, governanceAddr, maxEdges, rate, initialWhitelistedAssetIds];
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

        return new RewardManager(manager, signer, zkComponents, maxEdges);
    }

    // Get the current rate
    public async getRate(): Promise<BigNumber> {
        return await this.contract.rate();
    }

    // Set the rate (only callable by the governance)
    public async setRate(newRate: BigNumber): Promise<void> {
        const tx = await this.contract.setRates(newRate);
        await tx.wait();
    }

    // Set the pool weight (only callable by the governance)
    public async setPoolWeight(newWeight: BigNumber): Promise<void> {
        const tx = await this.contract.setPoolWeight(newWeight);
        await tx.wait();
    }

    // Update the whiteListedAssetIds (only callable by the governance)
    public async updateWhiteListedAssetIds(newAssetIds: BigNumber[]): Promise<void> {
        const tx = await this.contract.updateWhiteListedAssetIds(newAssetIds);
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

    // Update an existing edge with a new chainId (only callable by the governance)
    public async updateEdge(oldChainId: number, newChainId: number): Promise<void> {
        const tx = await this.contract.updateEdge(oldChainId, newChainId);
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
        const wtns = await this.zkComponents.witnessCalculator.calculateWTNSBin(
            rewardAllInputs,
            0
        );
        let res = await snarkjs.groth16.fullProve(this.zkComponents.zkey, wtns);
        const vKey = await snarkjs.zKey.exportVerificationKey(this.zkComponents.zkey);
        const verified = await snarkjs.groth16.verify(vKey, res.publicSignals, res.proof);
        assert.strictEqual(verified, true);
        return res;
    }

    // Helper function to hash `IMASPRewardExtData` to a field element
    public toRewardExtDataHash(
        fee: BigNumberish,
        recipient: string,
        relayer: string
    ): BigNumberish {
        const abi = new ethers.utils.AbiCoder();
        const encodedData = abi.encode(
            [
                'tuple(uint256 fee,address recipient,address relayer)',
            ],
            [
                {
                    fee: toFixedHex(fee),
                    recipient: toFixedHex(recipient, 20),
                    relayer: toFixedHex(relayer, 20),
                },
            ]
        );

        const hash = ethers.utils.keccak256(encodedData);
        return BigNumber.from(hash).mod(FIELD_SIZE);
    }

    // Helper function to compte rewardNullifier
    public computeRewardNullifier(
        maspNoteNullifier: BigNumber,
        maspNotePathIndices: BigNumber,
    ): BigNumber {
        return poseidon([maspNoteNullifier, maspNotePathIndices]);
    }

    // Generate MASP Reward Inputs
    public generateMASPRewardInputs(
        maspNote: MaspUtxo,
        maspNotePathIndices: BigNumber,
        rate: number,
        rewardNullifier: BigNumber,
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
        relayer: string): IMASPRewardAllInputs {

        const rewardAmount = maspNote.amount.mul(rate).mul(spentTimestamp - unspentTimestamp);
        const extDataHash = this.toRewardExtDataHash(fee, recipient, relayer);

        return {
            rate: rate,
            rewardAmount: rewardAmount,
            rewardNullifier: rewardNullifier,
            extDataHash: extDataHash,
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
        };
    }

    // This function is called by the relayer to claim the reward.
    // The relayer will receive the reward amount and the fee.
    // The recipient will receive the remaining amount.

    public async reward(
        maspNote: MaspUtxo,
        maspNotePathIndices: BigNumber,
        rate: number,
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
        relayer: string): Promise<ContractReceipt> {

        const rewardNullifier = this.computeRewardNullifier(
            maspNote.getNullifier(),
            maspNotePathIndices);

        const rewardAllInputs = this.generateMASPRewardInputs(
            maspNote,
            maspNotePathIndices,
            rate,
            rewardNullifier,
            spentTimestamp,
            spentRoots,
            spentPathIndices,
            spentPathElements,
            unspentTimestamp,
            unspentRoots,
            unspentPathIndices,
            unspentPathElements,
            fee,
            recipient,
            relayer
        );

        const proof = await this.generateRewardProof(rewardAllInputs);

        const tx = await this.contract.reward(
            proof.proof,
            proof.publicSignals
        );
        const receipt = await tx.wait();
        const event = receipt.events?.find((event) => event.event === 'RewardSwapped');
        if (!event) {
            throw new Error('RewardSwapped event not found');
        }
        return receipt;
    }
}