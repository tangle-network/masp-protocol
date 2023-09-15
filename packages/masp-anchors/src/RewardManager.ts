import { BigNumber, ethers } from 'ethers';
import {
    RewardManager as RewardManagerContract,
    RewardManager__factory,
} from '@webb-tools/masp-anchor-contracts';
import { getChainIdType, ZkComponents, toFixedHex } from '@webb-tools/utils';
import { QueueDepositInfo } from './interfaces';
import { Deployer } from '@webb-tools/create2-utils';

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

}