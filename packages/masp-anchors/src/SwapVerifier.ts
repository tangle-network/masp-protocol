import { ethers, Signer } from 'ethers';

import {
  SwapProofVerifier as SwapProofVerifierContract,
  SwapProofVerifier__factory,
  VerifierSwap_30_2__factory as v2__factory,
  VerifierSwap_30_8__factory as v8__factory,
} from '@webb-tools/masp-anchor-contracts';
import { Deployer } from '@webb-tools/create2-utils';

export class SwapProofVerifier {
  signer: ethers.Signer;
  contract: SwapProofVerifierContract;

  public constructor(contract: SwapProofVerifierContract, signer: ethers.Signer) {
    this.signer = signer;
    this.contract = contract;
  }
  public static async createVerifier(signer: Signer) {
    const v2Factory = new v2__factory(signer);
    const v2 = await v2Factory.deploy();
    await v2.deployed();

    const v8Factory = new v8__factory(signer);
    const v8 = await v8Factory.deploy();
    await v8.deployed();

    const factory = new SwapProofVerifier__factory(signer);
    const verifier = await factory.deploy(v2.address, v8.address);
    await verifier.deployed();
    return new SwapProofVerifier(verifier, signer);
  }

  public static async create2Verifiers(
    deployer: Deployer,
    saltHex: string,
    signer: Signer
  ): Promise<{ v2: SwapProofVerifierContract; v8: SwapProofVerifierContract }> {
    const { contract: v2 } = await deployer.deploy(v2__factory, saltHex, signer);
    const { contract: v8 } = await deployer.deploy(v8__factory, saltHex, signer);

    return { v2, v8 };
  }

  public static async create2SwapProofVerifier(
    deployer: Deployer,
    saltHex: string,
    signer: Signer,
    v2: SwapProofVerifierContract,
    v8: SwapProofVerifierContract
  ): Promise<SwapProofVerifier> {
    const argTypes = ['address', 'address'];
    const args = [v2.address, v8.address];

    const { contract: verifier } = await deployer.deploy(
      SwapProofVerifier__factory,
      saltHex,
      signer,
      undefined,
      argTypes,
      args
    );

    return new SwapProofVerifier(verifier, signer);
  }
}

export default SwapProofVerifier;
