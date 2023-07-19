import { ethers } from 'ethers';
import {
  MultiNftTokenManager as MultiNftTokenManagerContract,
  MultiNftTokenManager__factory,
} from '@webb-tools/masp-anchor-contracts';
import { Deployer } from '@webb-tools/create2-utils';

export class MultiNftTokenManager {
  contract: MultiNftTokenManagerContract;

  constructor(contract: MultiNftTokenManagerContract) {
    this.contract = contract;
  }

  public static async create2MultiNftTokenManager(
    deployer: Deployer,
    salt: string,
    signer: ethers.Signer
  ) {
    const saltHex = ethers.utils.id(salt);
    const { contract: manager } = await deployer.deploy(
      MultiNftTokenManager__factory,
      saltHex,
      signer
    );

    return new MultiNftTokenManager(manager);
  }

  public static async createMultiNftTokenManager(deployer: ethers.Signer) {
    const factory = new MultiNftTokenManager__factory(deployer);
    const contract = await factory.deploy();
    await contract.deployed();

    const manager = new MultiNftTokenManager(contract);
    return manager;
  }

  public static async connect(managerAddress: string, signer: ethers.Signer) {
    const managerContract = MultiNftTokenManager__factory.connect(managerAddress, signer);
    const manager = new MultiNftTokenManager(managerContract);
    return manager;
  }
}
