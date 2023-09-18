import { BigNumber, ethers } from 'ethers';
import {
    RewardManager as RewardManagerContract,
    RewardManager__factory,
} from '@webb-tools/masp-anchor-contracts';
import { getChainIdType, ZkComponents, toFixedHex } from '@webb-tools/utils';
import { Deployer } from '@webb-tools/create2-utils';
import { FullProof, IMASPRewardAllInputs } from './interfaces';
const assert = require('assert');
const snarkjs = require('snarkjs');

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
        saltHex: string,
        maspProxyAddr: string,
        verifierAddr: string,
        signer: ethers.Signer,
        zkComponents: ZkComponents,
        maxEdges: number
    ) {
        const argTypes = ['address'];
        const args = [verifierAddr];
        const { contract: manager } = await deployer.deploy(
            RewardManager__factory,
            saltHex,
            signer,
            undefined,
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

    public async generateSwapProof(rewardAllInputs: IMASPRewardAllInputs): Promise<FullProof> {
        const wtns = await this.zkComponents.witnessCalculator.calculateWTNSBin(
            rewardAllInputs,
            0
        );
        let res = await snarkjs.groth16.prove(this.zkComponents.zkey, wtns);
        const vKey = await snarkjs.zKey.exportVerificationKey(this.zkComponents.zkey);
        const verified = await snarkjs.groth16.verify(vKey, res.publicSignals, res.proof);
        assert.strictEqual(verified, true);
        return res;
    }

}