import { poseidon } from 'circomlibjs';
import { BigNumber } from 'ethers';
import { hexToU8a, Keypair, randomBN, toBuffer, toFixedHex, u8aToHex } from '@webb-tools/utils';

export type RewardUtxoGenInput = {
    amount: string;
    chainId: string;
    blinding?: Uint8Array;
    index?: string;
    keypair?: Keypair;
};

export class RewardUtxo {
    _keypair: Keypair = new Keypair();
    _amount = '';
    _chainId = '';
    _index?: number;
    _pubkey = '';
    _secret_key = '';
    _blinding = '';

    static generateUtxo(input: RewardUtxoGenInput): RewardUtxo {
        const utxo = new RewardUtxo();

        // Required parameters
        utxo._amount = input.amount;
        utxo._chainId = input.chainId;

        // Optional parameters
        utxo._index = input.index ? Number(input.index) : 0;

        if (input.keypair) {
            utxo.setKeypair(input.keypair);
        } else {
            // Populate the _pubkey and _secret_key values with
            // the random default keypair
            utxo.setKeypair(utxo.getKeypair());
        }

        utxo._blinding = input.blinding
            ? u8aToHex(input.blinding).slice(2)
            : toFixedHex(randomBN(31)).slice(2);

        return utxo;
    }

    get keypair(): Keypair {
        return this._keypair;
    }

    set keypair(keypair: Keypair) {
        this._keypair = keypair;
    }

    get amount(): string {
        return this._amount;
    }

    set amount(amount: string) {
        this._amount = amount;
    }

    get blinding(): string {
        return this._blinding;
    }

    set blinding(blinding: string) {
        this._blinding = blinding;
    }

    get chainId(): string {
        return this._chainId;
    }

    set chainId(chainId: string) {
        this._chainId = chainId;
    }

    /**
     * Returns commitment for this UTXO
     *
     * @returns the poseidon hash of [chainId, amount, pubKey, blinding]
     */
    get commitment(): Uint8Array {
        const hash = poseidon([
            this._chainId,
            this._amount,
            '0x' + this._pubkey,
            '0x' + this._blinding,
        ]);

        return hexToU8a(BigNumber.from(hash).toHexString());
    }

    /**
     * @returns the index configured on this UTXO. Output UTXOs generated
     * before they have been inserted in a tree.
     *
     */
    get index(): number {
        return this._index ?? -1;
    }

    set index(index: number) {
        this._index = index;
    }

    get public_key(): string {
        return this._pubkey;
    }

    /**
     * @returns the secret_key AKA private_key used in the nullifier.
     * this value is used to derive the public_key for the commitment.
     */
    get secret_key(): string {
        return this._secret_key;
    }

    set secret_key(secret: string) {
        this._secret_key = secret;
    }

    getKeypair(): Keypair {
        return this._keypair;
    }

    setKeypair(keypair: Keypair): void {
        this._pubkey = keypair.getPubKey().slice(2);

        if (keypair.privkey) {
            this._secret_key = keypair.privkey.slice(2);
        }

        this._keypair = keypair;
    }

    setIndex(val: number): void {
        this.index = val;
    }

    /**
      * @returns the nullifier: hash of [commitment, index, signature] as decimal string
      * where signature = hash([secret key, commitment, index])
      */
    public nullifier(maspNoteAk_X: string, maspNoteAk_Y: string): string {
        // If the amount of the UTXO is zero, then the nullifier is not important.
        // Return a 'dummy' value that will satisfy the circuit
        // Enforce index on the UTXO if there is an amount greater than zero
        if (!this.getKeypair() || !this.getKeypair().privkey) {
            throw new Error('Cannot create nullifier, keypair with private key not configured');
        }

        const x = poseidon([
            maspNoteAk_X, maspNoteAk_Y,
            u8aToHex(this.commitment)
        ]);

        return toFixedHex(x).slice(2);
    }
}
