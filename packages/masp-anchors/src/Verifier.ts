import { ethers } from 'ethers';

import {
  MASPVAnchorVerifier__factory,
  MASPVAnchorVerifier as VerifierContract,
  VerifierMASP2_2__factory,
  VerifierMASP8_2__factory,
  VerifierMASP2_16__factory,
  VerifierMASP8_16__factory,
} from '@webb-tools/masp-anchor-contracts';
import { Deployer } from '@webb-tools/create2-utils';

export class MultiAssetVerifier {
  signer: ethers.Signer;
  contract: VerifierContract;

  public constructor(contract: VerifierContract, signer: ethers.Signer) {
    this.signer = signer;
    this.contract = contract;
  }

  public static async create2Verifiers(
    deployer: Deployer,
    saltHex: string,
    v22__factory: any,
    v82__factory: any,
    v216__factory: any,
    v816__factory: any,
    signer: ethers.Signer
  ): Promise<{ v22; v82; v216; v816 }> {
    const { contract: v22 } = await deployer.deploy(v22__factory, saltHex, signer);
    const { contract: v82 } = await deployer.deploy(v82__factory, saltHex, signer);
    const { contract: v216 } = await deployer.deploy(v216__factory, saltHex, signer);
    const { contract: v816 } = await deployer.deploy(v816__factory, saltHex, signer);

    return { v22, v82, v216, v816 };
  }

  public static async create2VAnchorVerifier(
    deployer: Deployer,
    saltHex: string,
    verifier__factory: any,
    signer: ethers.Signer,
    { v22, v82, v216, v816 }
  ): Promise<VerifierContract> {
    const argTypes = ['address', 'address', 'address', 'address'];
    const args = [v22.address, v216.address, v82.address, v816.address];

    const { contract: verifier } = await deployer.deploy(
      verifier__factory,
      saltHex,
      signer,
      undefined,
      argTypes,
      args
    );
    return verifier;
  }

  public static async create2Verifier(deployer: Deployer, saltHex: string, signer: ethers.Signer) {
    const verifiers = await this.create2Verifiers(
      deployer,
      saltHex,
      VerifierMASP2_2__factory,
      VerifierMASP8_2__factory,
      VerifierMASP2_16__factory,
      VerifierMASP8_16__factory,
      signer
    );

    const verifier = await this.create2VAnchorVerifier(
      deployer,
      saltHex,
      MASPVAnchorVerifier__factory,
      signer,
      verifiers
    );
    const createdVerifier = new MultiAssetVerifier(verifier, signer);
    return createdVerifier;
  }

  // Deploys a Verifier contract and all auxiliary verifiers used by this verifier
  public static async createVerifier(signer: ethers.Signer) {
    const v22Factory = new VerifierMASP2_2__factory(signer);
    const v22 = await v22Factory.deploy();
    await v22.deployed();
    const v82Factory = new VerifierMASP8_2__factory(signer);
    const v82 = await v82Factory.deploy();
    await v82.deployed();
    const v216Factory = new VerifierMASP2_16__factory(signer);
    const v216 = await v216Factory.deploy();
    await v216.deployed();
    const v816Factory = new VerifierMASP8_16__factory(signer);
    const v816 = await v816Factory.deploy();
    await v816.deployed();
    const factory = new MASPVAnchorVerifier__factory(signer);
    const verifier = await factory.deploy(v22.address, v216.address, v82.address, v816.address);
    await verifier.deployed();
    const createdVerifier = new MultiAssetVerifier(verifier, signer);

    return createdVerifier;
  }
}

export default MultiAssetVerifier;
