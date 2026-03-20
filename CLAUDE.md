# CLAUDE.md — MASP Protocol

## Project Overview

Multi-Asset Shielded Pool (MASP) protocol extending the Webb VAnchor system. Supports multiple asset types in a single shielded pool with in-circuit fee payment, cross-chain bridging, shielded rewards, and atomic swaps.

**Status:** Legacy research implementation. Circuits compile but the project is not actively maintained. Originally built as Webb Protocol's next-generation privacy system.

## Architecture

### Circuit Hierarchy

```
masp-vanchor/
  transaction.circom    — Main MASP transaction (multi-asset UTXO + fee UTXO)
  record.circom         — UTXO commitment: Record, PartialRecord, InnerPartialRecord
  nullifier.circom      — Nullifier derivation (EdDSA-based, different from VAnchor)
  key.circom            — Key derivation (ak_X, ak_Y → pk_X, pk_Y via Poseidon)
  reward.circom         — Anonymity mining / shielded rewards
  swap.circom           — Atomic shielded swaps between two parties
  babypow.circom        — BabyJubJub power computation for rewards
```

### Key Differences from VAnchor (protocol-solidity)

| Feature | VAnchor | MASP |
|---------|---------|------|
| Asset types | Single token per pool | Multi-asset (assetID + tokenID per UTXO) |
| Key scheme | Poseidon(sk) → pk | EdDSA BabyJubJub (ak_X, ak_Y → pk_X, pk_Y) |
| Nullifier | H(cm, path, H(sk, path, cm)) | H(ak_X, ak_Y, record) via Nullifier template |
| Fee payment | External (relayer) | In-circuit (separate fee UTXO track) |
| Signatures | None in circuit | EdDSA Poseidon for both input and output authorization |
| Rewards | None | Anonymity mining via time-weighted deposit proof |
| Swaps | None | Atomic shielded swaps |
| Commitment | H(chainID, amount, pk, blinding) | H(assetID, tokenID, amount, H(chainID, pk_X, pk_Y, H(blinding))) |

### Commitment Structure (Nested Hashing)

```
InnerPartialRecord = Poseidon(blinding)
PartialRecord = Poseidon(chainID, pk_X, pk_Y, InnerPartialRecord)
Record = Poseidon(assetID, tokenID, amount, PartialRecord)
```

This 3-level nesting allows proving properties about partial commitments without revealing everything.

### Reward Mechanism

The reward circuit (`reward.circom`) implements anonymity mining:
- User proves they held a deposit between `unspentTimestamp` and `spentTimestamp`
- Reward = `(spentTimestamp - unspentTimestamp) × selectedRewardRate`
- The reward rate is selected from a public list of valid rates per asset
- A `rewardNullifier` prevents double-claiming

The mechanism incentivizes keeping deposits in the pool longer, which grows the anonymity set.

### Swap Mechanism

The swap circuit (`swap.circom`) enables atomic cross-asset exchanges within the shielded pool:
- Party A commits to swap X of asset A for Y of asset B
- Party B provides the matching commitment
- The circuit verifies both sides atomically

## Build & Test

```bash
# Install dependencies
yarn install

# Compile circuits (requires circom 2.0+)
yarn build:circuits

# Run Solidity tests
forge test

# Run TypeScript tests
yarn test
```

## Key Files

| File | Purpose |
|------|---------|
| `circuits/masp-vanchor/transaction.circom` | Core MASP transaction circuit |
| `circuits/masp-vanchor/reward.circom` | Anonymity mining reward circuit |
| `circuits/masp-vanchor/swap.circom` | Atomic shielded swap circuit |
| `circuits/masp-vanchor/record.circom` | UTXO commitment construction |
| `circuits/masp-vanchor/nullifier.circom` | EdDSA-based nullifier derivation |
| `circuits/masp-vanchor/key.circom` | BabyJubJub key derivation |

## Research Questions (Open)

1. **Reward mechanism soundness:** Is the time-weighted anonymity mining incentive-compatible? Can users game it by rapidly depositing/withdrawing across epochs?
2. **Fee circuit complexity:** The dual-track (main UTXO + fee UTXO) doubles the circuit size. Is this justified vs external fee payment?
3. **Swap privacy:** Does the swap circuit leak correlation between the two parties? The matching commitment structure may allow observers to link swap counterparties.
4. **Constraint count:** The MASP transaction circuit is significantly larger than the VAnchor. What's the compilation time and proof generation cost?
