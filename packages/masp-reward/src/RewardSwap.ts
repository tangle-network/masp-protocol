import { BigNumber, ethers } from 'ethers';
import { RewardSwap as RewardSwapContract, RewardSwap__factory } from '@webb-tools/masp-anchor-contracts';
import { RewardManager } from './RewardManager';
import { Deployer } from '@webb-tools/create2-utils';

export class RewardSwap {
    contract: RewardSwapContract;
    signer: ethers.Signer;
    rewardManager: RewardManager;

    // Constructor
    public constructor(contract: RewardSwapContract, signer: ethers.Signer, rewardManager: RewardManager) {
        this.contract = contract;
        this.signer = signer;
        this.rewardManager = rewardManager;
    }

    // Deploy a new RewardSwap contract
    public static async create2RewardSwap(
        deployer: Deployer,
        tangleAddr: string,
        manager: RewardManager,
        miningCap: BigNumber,
        initialLiquidity: BigNumber,
        poolWeight: BigNumber
    ) {
        const argTypes = ['address', 'address', 'uint256', 'uint256', 'uint256'];
        const args = [tangleAddr, manager.contract.address, miningCap, initialLiquidity, poolWeight];
        const { contract: swap } = await deployer.deploy(
            RewardSwap__factory,
            undefined,
            manager.signer,
            undefined,
            argTypes,
            args
        );

        return new RewardSwap(swap, manager.signer, manager);
    }

    // Swap tokens and return the amount of TNT received
    public async swapTokens(recipient: string, amount: BigNumber): Promise<BigNumber> {
        const tx = await this.contract.swap(recipient, amount);
        await tx.wait();

        // Assuming that the contract emits an event with the amount of TNT received
        const receipt = await tx.wait();
        const event = receipt.events?.find((e) => e.event === 'Swap');
        if (!event) {
            throw new Error('Swap event not found');
        }

        const tntReceived = event.args?.[2];
        if (!tntReceived) {
            throw new Error('TNT received not found in Swap event');
        }

        return tntReceived;
    }

    // Get the expected TNT return for a given amount of tokens
    public async getExpectedTntReturn(amount: BigNumber): Promise<BigNumber> {
        return await this.contract.getExpectedReturn(amount);
    }

    // Get the virtual TNT balance
    public async getVirtualTntBalance(): Promise<BigNumber> {
        return await this.contract.tntVirtualBalance();
    }

    // Set the pool weight (only callable by the RewardManager)
    public async setPoolWeight(newWeight: BigNumber): Promise<void> {
        const tx = await this.contract.setPoolWeight(newWeight);
        await tx.wait();
    }

    // Get the current pool weight
    public async getPoolWeight(): Promise<BigNumber> {
        return await this.contract.poolWeight();
    }

    // Get the start timestamp
    public async getStartTimestamp(): Promise<BigNumber> {
        return await this.contract.startTimestamp();
    }

    // Get the duration
    public async getDuration(): Promise<BigNumber> {
        return BigNumber.from(365).mul(24).mul(60).mul(60); // 365 days in seconds
    }
}
