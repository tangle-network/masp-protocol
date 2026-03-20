# Architecture: Rebuilding the Shielded Payment Protocol

## The Case for SP1 zkVM

### Why Rebuild

The current system uses three separate circom circuits (VAnchor + RLN + glue) composed via constraint wiring. This works but has fundamental limitations:

1. **Frozen logic** — Any change requires a new trusted setup ceremony
2. **No batching** — Each user generates and verifies their own proof (270k gas each)
3. **Circom limitations** — No loops, no dynamic dispatch, no standard library
4. **Dual audit surface** — Circom circuits + Solidity contracts, two languages to audit
5. **MASP complexity** — The multi-asset circuit doubles in size due to the fee UTXO track

### What SP1 Enables

Write the entire protocol in Rust. Prove it with SP1. Verify on-chain with a single Groth16 wrapper.

| Property | Circom (current) | SP1 (proposed) |
|----------|-----------------|----------------|
| Language | Circom DSL | Rust |
| Trusted setup | Required (per circuit change) | None (STARKs are transparent) |
| Proof generation | Client CPU only | Succinct Prover Network (GPU cluster) |
| Batching | Not possible | Natural (prove N txs in one proof) |
| On-chain verification | ~270k gas per proof | ~270k gas per BATCH |
| Updateability | Redeploy + ceremony | Redeploy program only |
| Testing | snarkjs (JS) | cargo test (Rust) |
| Debugging | Poor (constraint failures) | Full Rust stack traces |

### What Stays the Same

- Poseidon hash function (SP1 has accelerated precompiles)
- BN254 curve (SP1's Groth16 wrapper uses BN254)
- Merkle tree structure (30 levels, same zero values)
- UTXO commitment scheme (can keep exact same hash structure)
- Cross-chain root membership proof
- ERC20 token wrapping

## Proposed Architecture

### Layer 1: SP1 Shielded Pool Program

A single Rust program that SP1 proves:

```rust
// sp1-shielded-pool/src/main.rs
fn main() {
    // Read private inputs from SP1 stdin
    let txs: Vec<ShieldedTransaction> = sp1_zkvm::io::read();
    let merkle_roots: Vec<[u8; 32]> = sp1_zkvm::io::read();

    for tx in &txs {
        // 1. Verify UTXO commitments
        verify_commitments(tx);

        // 2. Verify Merkle membership
        verify_merkle_proof(tx, &merkle_roots);

        // 3. Verify nullifier correctness
        verify_nullifier(tx);

        // 4. Verify amount conservation
        verify_conservation(tx);

        // 5. Verify RLN rate-limiting (optional)
        if let Some(rln) = &tx.rln {
            verify_rln(rln, tx);
        }

        // 6. Verify MASP multi-asset constraints (optional)
        if let Some(masp) = &tx.masp {
            verify_multi_asset(masp, tx);
            verify_fee_payment(masp, tx);
        }
    }

    // Commit public outputs
    sp1_zkvm::io::commit(&txs.iter().map(|t| t.nullifiers()).collect());
    sp1_zkvm::io::commit(&txs.iter().map(|t| t.output_commitments()).collect());
}
```

### Layer 2: Batch Verifier Contract

```solidity
contract ShieldedPoolV2 {
    ISP1Verifier public verifier;  // Succinct's on-chain verifier
    bytes32 public programVKey;    // SP1 program verification key

    // One proof verifies N transactions
    function processBatch(
        bytes calldata proof,
        bytes calldata publicValues  // nullifiers + commitments for all N txs
    ) external {
        verifier.verifyProof(programVKey, publicValues, proof);

        // Extract and process all nullifiers + commitments from publicValues
        (bytes32[] memory nullifiers, bytes32[] memory commitments) =
            abi.decode(publicValues, (bytes32[], bytes32[]));

        for (uint i = 0; i < nullifiers.length; i++) {
            require(!isSpent[nullifiers[i]], "spent");
            isSpent[nullifiers[i]] = true;
        }

        for (uint i = 0; i < commitments.length; i++) {
            _insert(commitments[i]);
        }
    }
}
```

### Layer 3: Client SDK

The client generates transaction witnesses in Rust and submits to:
- **Local proving** — SP1's local prover for development
- **Succinct Prover Network** — GPU cluster for production (proof in <10s)
- **Self-hosted GPU** — For operators who want to run their own prover

## Feature Matrix: What to Build

### Phase 1: Core Pool (replaces VAnchor)
- [ ] Poseidon hash in Rust (use `sp1-primitives` precompile)
- [ ] UTXO commitment: `H(chainID, amount, pubKey, blinding)` — same as VAnchor
- [ ] Nullifier: `H(commitment, pathIndex, H(sk, pathIndex, commitment))` — same
- [ ] Merkle membership proof (30 levels)
- [ ] Cross-chain root membership (8 roots)
- [ ] JoinSplit (2-in-2-out)
- [ ] Amount conservation
- [ ] Batch verification (N transactions in one proof)

### Phase 2: RLN Integration
- [ ] RLN nullifier: `H(sk, H(epoch, chainID))`
- [ ] Shamir share computation
- [ ] Solvency constraint
- [ ] EdDSA refund receipt verification

### Phase 3: MASP Features (from masp-protocol)
- [ ] Multi-asset support: `Record = H(assetID, tokenID, amount, partialRecord)`
- [ ] In-circuit fee payment (separate fee UTXO track)
- [ ] Asset-specific constraints (public/shielded asset matching)
- [ ] Cross-asset atomic swaps

### Phase 4: Advanced Features
- [ ] Shielded rewards / anonymity mining (from reward.circom)
- [ ] Recursive proofs (prove a proof is valid — for proof aggregation)
- [ ] NFT support (tokenID as unique identifier)
- [ ] Compliance hooks (optional disclosure to auditors via viewing keys)

## Gas Cost Projection

| Scenario | Current (circom) | SP1 (single) | SP1 (batch 10) | SP1 (batch 100) |
|----------|-----------------|--------------|-----------------|------------------|
| 1 transaction | 270k gas | 270k gas | — | — |
| 10 transactions | 2.7M gas | — | 270k gas | — |
| 100 transactions | 27M gas | — | — | 270k gas |
| Per-user cost (batch 10) | 270k | — | 27k | — |
| Per-user cost (batch 100) | 270k | — | — | 2.7k |

The rollup-style batching is the killer feature. 100x gas reduction per user.

## What We Lose

1. **Audited circuits** — Need to re-audit the Rust implementation (but SP1 itself is audited)
2. **Proof generation locality** — SP1 proofs are heavier than Groth16; may need prover network for sub-second proving
3. **Ceremony-based trust** — Groth16 trusted setup provides a specific trust model; SP1's STARK transparency is different (arguably better)

## What We Gain

1. **No trusted setup** — Deploy and iterate without ceremonies
2. **Batching** — 10-100x cheaper per user
3. **Rust ecosystem** — Standard testing, debugging, CI/CD
4. **Updateability** — Change logic without redeployment ceremony
5. **MASP for free** — Multi-asset support is just Rust code, not circuit redesign
6. **Prover network** — Outsource heavy proving to Succinct's GPU infrastructure
7. **Composability** — The SP1 program can call any Rust crate (HTTP, JSON, crypto)

## Open Questions

1. **Proof generation latency** — SP1 proofs for 49k+ equivalent constraints: how fast on the prover network?
2. **Data availability** — Batch proofs need DA for the transaction data. Use EIP-4844 blobs?
3. **Sequencer** — Who batches transactions? The operator? A decentralized sequencer?
4. **MEV** — Can the sequencer front-run or censor shielded transactions?
5. **Backwards compatibility** — Can SP1 verify existing circom-generated proofs? (No — different proof system. Migration required.)
