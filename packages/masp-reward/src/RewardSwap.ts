import { BigNumber, ethers } from 'ethers';
import {
  RewardSwap as RewardSwapContract,
  RewardSwap__factory,
} from '@webb-tools/masp-anchor-contracts';
import { Deployer } from '@webb-tools/create2-utils';

export class RewardSwap {
  contract: RewardSwapContract;

  // Constructor
  public constructor(contract: RewardSwapContract) {
    this.contract = contract;
  }

  // Deploy a new RewardSwap contract
  public static async create2RewardSwap(
    deployer: Deployer,
    signer: ethers.Signer,
    saltHex: string,
    governance: string,
    tangleAddr: string,
    miningCap: BigNumber,
    initialLiquidity: BigNumber,
    poolWeight: number
  ) {
    const argTypes = ['address', 'address', 'uint256', 'uint256', 'uint256'];
    const args = [governance, tangleAddr, miningCap, initialLiquidity, poolWeight];
    const { contract: rewardSwapContract } = await deployer.deploy(
      RewardSwap__factory,
      saltHex,
      signer,
      undefined,
      argTypes,
      args
    );

    return new RewardSwap(rewardSwapContract);
  }

  // Initialize the RewardSwap contract
  public async initialize(rewardManagerAddress: string) {
    const tx = await this.contract.initialize(rewardManagerAddress);
    await tx.wait();
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
