import { BigNumber, BigNumberish, ContractReceipt, ethers } from 'ethers';
const assert = require('assert');
const snarkjs = require('snarkjs');
import { poseidon } from 'circomlibjs';
import {
    RewardManager as RewardManagerContract,
    RewardManager__factory,
    RewardEncodeInputs__factory
} from '@webb-tools/masp-anchor-contracts';
import { maspRewardFixtures } from '@webb-tools/protocol-solidity-extension-utils';
import { getChainIdType, ZkComponents, toFixedHex, FIELD_SIZE } from '@webb-tools/utils';
import { Deployer } from '@webb-tools/create2-utils';
import { MaspUtxo } from '@webb-tools/masp-anchors';
import { IMASPRewardExtData, IMASPRewardAllInputs } from './interfaces';
import RewardProofVerifier from './RewardVerifier';

const maspRewardZkComponents = maspRewardFixtures('../../../solidity-fixtures/solidity-fixtures');

export class RewardManager {
    contract: RewardManagerContract;
    signer: ethers.Signer;
    zkComponents: ZkComponents;
    maxEdges: number;
    whitelistedAssetIDs: number[];

    // Constructor
    public constructor(contract: RewardManagerContract, signer: ethers.Signer, zkComponents: ZkComponents, maxEdges: number, whitelistedAssetIDs: number[]
    ) {
        this.contract = contract;
        this.signer = signer;
        this.zkComponents = zkComponents;
        this.maxEdges = maxEdges;
        this.whitelistedAssetIDs = whitelistedAssetIDs;
    }

    // Deploy a new RewardManager
    public static async createRewardManager(
        deployer: Deployer,
        signer: ethers.Signer,
        saltHex: string,
        rewardSwapContractAddr: string,
        rewardVerifierContract: RewardProofVerifier,
        governanceAddr: string,
        maxEdges: number,
        rate: number,
        initialWhitelistedAssetIds: number[]
    ) {
        let zkComponents: ZkComponents;

        if (maxEdges == 2) {
            zkComponents = await maspRewardZkComponents[230]();
        } else if (maxEdges == 8) {
            zkComponents = await maspRewardZkComponents[830]();
        } else {
            throw new Error('maxEdges must be 2 or 8');
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
        const manager = await factory.deploy(rewardSwapContractAddr, rewardVerifierContract.contract.address, governanceAddr, maxEdges, rate, initialWhitelistedAssetIds);
        await manager.deployed();

        return new RewardManager(manager, signer, zkComponents, maxEdges, initialWhitelistedAssetIds);
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
        maxEdges: number,
        rate: number,
        initialWhitelistedAssetIds: number[]
    ) {
        let zkComponents: ZkComponents;

        if (maxEdges == 2) {
            zkComponents = await maspRewardZkComponents[230]();
        } else if (maxEdges == 8) {
            zkComponents = await maspRewardZkComponents[830]();
        } else {
            throw new Error('maxEdges must be 2 or 8');
        }

        const argTypes = ['address', 'address', 'address', 'uint8', 'uint256', 'uint32[]'];
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

        return new RewardManager(manager, signer, zkComponents, maxEdges, initialWhitelistedAssetIds);
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

    // Update the whitelistedAssetIds (only callable by the governance)
    public async updateWhiteListedAssetIds(newAssetIds: BigNumber[]): Promise<void> {
        const tx = await this.contract.updatewhitelistedAssetIDs(newAssetIds);
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
    public toRewardExtDataHash(
        extData: IMASPRewardExtData
    ): BigNumberish {
        const abi = new ethers.utils.AbiCoder();
        const encodedData = abi.encode(
            [
                'uint256', 'address', 'address'
            ],
            [
                extData.fee,
                extData.recipient,
                extData.relayer

            ]
        );

        const hash = ethers.utils.keccak256(encodedData);
        return BigNumber.from(hash).mod(FIELD_SIZE);
    }

    // Helper function to compte rewardNullifier
    public computeRewardNullifier(
        maspNoteNullifier: BigNumber,
        maspNotePathIndices: number,
    ): BigNumber {
        return poseidon([maspNoteNullifier, maspNotePathIndices]);
    }

    // Generate MASP Reward Inputs
    public generateMASPRewardInputs(
        maspNote: MaspUtxo,
        maspNotePathIndices: number,
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
        extData: IMASPRewardExtData): IMASPRewardAllInputs {

        const anonymityRewardPoints = maspNote.amount.mul(rate).mul(spentTimestamp - unspentTimestamp);
        const extDataHash = this.toRewardExtDataHash(extData);

        return {
            rate: rate,
            anonymityRewardPoints: anonymityRewardPoints,
            rewardNullifier: rewardNullifier,
            extDataHash: extDataHash,
            whitelistedAssetIDs: this.whitelistedAssetIDs,
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
        maspNotePathIndices: number,
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

        const extData: IMASPRewardExtData = {
            fee: fee,
            recipient: recipient,
            relayer: relayer,
        };

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
            extData
        );

        const { proofEncoded, publicSignals } = await this.generateRewardProof(rewardAllInputs);

        const tx = await this.contract.reward(
            proofEncoded,
            {
                rate: publicSignals[0],
                anonymityRewardPoints: publicSignals[1],
                rewardNullifier: publicSignals[2],
                extDataHash: publicSignals[3],
                whitelistedAssetIDs: RewardManager.createBNArrayToBytes(this.whitelistedAssetIDs),
                spentRoots: RewardManager.createBNArrayToBytes(spentRoots),
                unspentRoots: RewardManager.createBNArrayToBytes(unspentRoots),
            },
            extData
        );
        const receipt = await tx.wait();
        return receipt;
    }

    public static createBNArrayToBytes(arr: BigNumberish[]) {
        let result = '0x';
        for (let i = 0; i < arr.length; i++) {
            result += toFixedHex(arr[i]).substr(2);
        }
        return result; // root byte string (32 * array.length bytes)
    }
}