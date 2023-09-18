import { ethers, Signer } from 'ethers';

import {
    RewardProofVerifier as RewardProofVerifierContract,
    RewardProofVerifier__factory,
    VerifierReward_30_2__factory as v2_30__factory,
    VerifierReward_30_8__factory as v8_30__factory,
} from '@webb-tools/masp-anchor-contracts';
import { Deployer } from '@webb-tools/create2-utils';

export class RewardProofVerifier {
    signer: ethers.Signer;
    contract: RewardProofVerifierContract;

    public constructor(contract: RewardProofVerifierContract, signer: ethers.Signer) {
        this.signer = signer;
        this.contract = contract;
    }
    public static async createVerifier(signer: Signer) {
        const v2_30_Factory = new v2_30__factory(signer);
        const v2_30 = await v2_30_Factory.deploy();
        await v2_30.deployed();

        const v8_30_Factory = new v8_30__factory(signer);
        const v8_30 = await v8_30_Factory.deploy();
        await v8_30.deployed();

        const factory = new RewardProofVerifier__factory(signer);
        const verifier = await factory.deploy(v2_30.address, v8_30.address);
        await verifier.deployed();
        return new RewardProofVerifier(verifier, signer);
    }

    public static async create2Verifiers(
        deployer: Deployer,
        saltHex: string,
        signer: Signer
    ): Promise<{ v2_30: RewardProofVerifierContract; v8_30: RewardProofVerifierContract }> {
        const { contract: v2_30 } = await deployer.deploy(v2_30__factory, saltHex, signer);
        const { contract: v8_30 } = await deployer.deploy(v8_30__factory, saltHex, signer);

        return { v2_30, v8_30 };
    }

    public static async create2RewardProofVerifier(
        deployer: Deployer,
        saltHex: string,
        signer: Signer,
        v2_30: RewardProofVerifierContract,
        v8_30: RewardProofVerifierContract
    ): Promise<RewardProofVerifier> {
        const argTypes = ['address', 'address'];
        const args = [v2_30.address, v8_30.address];

        const { contract: verifier } = await deployer.deploy(
            RewardProofVerifier__factory,
            saltHex,
            signer,
            undefined,
            argTypes,
            args
        );

        return new RewardProofVerifier(verifier, signer);
    }
}

export default RewardProofVerifier;
