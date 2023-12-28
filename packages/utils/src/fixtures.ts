import { ZkComponents } from '@webb-tools/utils';
import fs from 'fs';
import path from 'path';

const snarkjs = require('snarkjs');

export async function fetchComponentsFromFilePaths(
  wasmPath: string,
  witnessCalculatorPath: string,
  zkeyPath: string
): Promise<ZkComponents> {
  const wasm: Buffer = fs.readFileSync(pr(wasmPath));
  const witnessCalculatorGenerator = await import(witnessCalculatorPath);
  const witnessCalculator = await witnessCalculatorGenerator.default(wasm);
  const zkeyBuffer: Buffer = fs.readFileSync(pr(zkeyPath));
  const zkey: Uint8Array = new Uint8Array(
    zkeyBuffer.buffer.slice(zkeyBuffer.byteOffset, zkeyBuffer.byteOffset + zkeyBuffer.byteLength)
  );

  return {
    wasm,
    witnessCalculator,
    zkey,
  };
}

const ZKEY_NAME = 'circuit_final.zkey';
const WITNESS_CALCULATOR_NAME = 'witness_calculator.cjs';

const MASP_VANCHOR_WASM = (ins: number, size: number) => `masp_vanchor_${ins}_${size}.wasm`;
const MASP_VANCHOR_WITNESS_CALCULATOR = (ins: number, size: number) =>
  `masp_vanchor_${ins}_${size}_${WITNESS_CALCULATOR_NAME}`;
const MASP_VANCHOR_CIRCUIT_FINAL = (ins: number, size: number) =>
  `masp_vanchor_${ins}_${size}_${ZKEY_NAME}`;

const MASP_SWAP_WASM = (w: number, depth: number) => `swap_${depth}_${w}.wasm`;
const MASP_SWAP_WITNESS_CALCULATOR = (w: number, depth: number) =>
  `swap_${depth}_${w}_${WITNESS_CALCULATOR_NAME}`;
const MASP_SWAP_CIRCUIT_FINAL = (w: number, depth: number) => `swap_${depth}_${w}_${ZKEY_NAME}`;

const MASP_REWARD_WASM = (w: number, depth: number) => `reward_${depth}_${w}.wasm`;
const MASP_REWARD_WITNESS_CALCULATOR = (w: number, depth: number) =>
  `reward_${depth}_${w}_${WITNESS_CALCULATOR_NAME}`;
const MASP_REWARD_CIRCUIT_FINAL = (w: number, depth: number) => `reward_${depth}_${w}_${ZKEY_NAME}`;

const BATCH_TREE_WASM = (size: number) => `batch_tree_${size}.wasm`;
const BATCH_TREE_WITNESS_CALCULATOR = (size: number) =>
  `batch_tree_${size}_${WITNESS_CALCULATOR_NAME}`;
const BATCH_TREE_CIRCUIT_FINAL = (size: number) => `batch_tree_${size}_${ZKEY_NAME}`;

// path.resolve(...)
const pr = (pathStr: string) => path.resolve(__dirname, pathStr);
// snarkjs.zKey.exportVerificationKey(...)
const expVkey = async (pathStr: string) => await snarkjs.zKey.exportVerificationKey(pr(pathStr));

export const maspVAnchorFixtures = (prefix) => ({
  prove_2_2: async (witness) =>
    snarkjs.groth16.prove(
      pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_CIRCUIT_FINAL(2, 2)}`),
      witness
    ),
  vkey_2_2: async () =>
    await expVkey(pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_CIRCUIT_FINAL(2, 2)}`)),
  2_2: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_WASM(2, 2)}`),
      pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_WITNESS_CALCULATOR(2, 2)}`),
      pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_CIRCUIT_FINAL(2, 2)}`)
    ),
  prove_16_2: async (witness) =>
    snarkjs.groth16.prove(
      pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_CIRCUIT_FINAL(16, 2)}`),
      witness
    ),
  vkey_16_2: async () =>
    await expVkey(pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_CIRCUIT_FINAL(16, 2)}`)),
  16_2: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_WASM(16, 2)}`),
      pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_WITNESS_CALCULATOR(16, 2)}`),
      pr(`${prefix}/masp_vanchor/2/${MASP_VANCHOR_CIRCUIT_FINAL(16, 2)}`)
    ),
  prove_2_8: async (witness) =>
    snarkjs.groth16.prove(
      pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_CIRCUIT_FINAL(2, 8)}`),
      witness
    ),
  vkey_2_8: async () =>
    await expVkey(pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_CIRCUIT_FINAL(2, 8)}`)),
  2_8: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_WASM(2, 8)}`),
      pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_WITNESS_CALCULATOR(2, 8)}`),
      pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_CIRCUIT_FINAL(2, 8)}`)
    ),
  prove_16_8: async (witness) =>
    snarkjs.groth16.prove(
      pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_CIRCUIT_FINAL(16, 8)}`),
      witness
    ),
  vkey_16_8: async () =>
    await expVkey(pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_CIRCUIT_FINAL(16, 8)}`)),
  16_8: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_WASM(16, 8)}`),
      pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_WITNESS_CALCULATOR(16, 8)}`),
      pr(`${prefix}/masp_vanchor/8/${MASP_VANCHOR_CIRCUIT_FINAL(16, 8)}`)
    ),
});

export const maspSwapFixtures = (prefix) => ({
  prove_2_30: async (witness) =>
    snarkjs.groth16.prove(pr(`${prefix}/swap/2/${MASP_SWAP_CIRCUIT_FINAL(2, 30)}`), witness),
  vkey_2_30: async () => await expVkey(pr(`${prefix}/swap/2/${MASP_SWAP_CIRCUIT_FINAL(2, 30)}`)),
  2_30: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/swap/2/${MASP_SWAP_WASM(2, 30)}`),
      pr(`${prefix}/swap/2/${MASP_SWAP_WITNESS_CALCULATOR(2, 30)}`),
      pr(`${prefix}/swap/2/${MASP_SWAP_CIRCUIT_FINAL(2, 30)}`)
    ),
  prove_8_30: async (witness) =>
    snarkjs.groth16.prove(pr(`${prefix}/swap/8/${MASP_SWAP_CIRCUIT_FINAL(8, 30)}`), witness),
  vkey_8_30: async () => await expVkey(pr(`${prefix}/swap/8/${MASP_SWAP_CIRCUIT_FINAL(8, 30)}`)),
  8_30: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/swap/8/${MASP_SWAP_WASM(8, 30)}`),
      pr(`${prefix}/swap/8/${MASP_SWAP_WITNESS_CALCULATOR(8, 30)}`),
      pr(`${prefix}/swap/8/${MASP_SWAP_CIRCUIT_FINAL(8, 30)}`)
    ),
});

export const maspRewardFixtures = (prefix) => ({
  prove_2_30: async (witness) =>
    snarkjs.groth16.prove(pr(`${prefix}/reward/2/${MASP_REWARD_CIRCUIT_FINAL(2, 30)}`), witness),
  vkey_2_30: async () =>
    await expVkey(pr(`${prefix}/reward/2/${MASP_REWARD_CIRCUIT_FINAL(2, 30)}`)),
  2_30: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/reward/2/${MASP_REWARD_WASM(2, 30)}`),
      pr(`${prefix}/reward/2/${MASP_REWARD_WITNESS_CALCULATOR(2, 30)}`),
      pr(`${prefix}/reward/2/${MASP_REWARD_CIRCUIT_FINAL(2, 30)}`)
    ),
  prove_8_30: async (witness) =>
    snarkjs.groth16.prove(pr(`${prefix}/reward/8/${MASP_REWARD_CIRCUIT_FINAL(8, 30)}`), witness),
  vkey_8_30: async () =>
    await expVkey(pr(`${prefix}/reward/8/${MASP_REWARD_CIRCUIT_FINAL(8, 30)}`)),
  8_30: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/reward/8/${MASP_REWARD_WASM(8, 30)}`),
      pr(`${prefix}/reward/8/${MASP_REWARD_WITNESS_CALCULATOR(8, 30)}`),
      pr(`${prefix}/reward/8/${MASP_REWARD_CIRCUIT_FINAL(8, 30)}`)
    ),
});

export const batchTreeFixtures = (prefix) => ({
  prove_4: async (witness) =>
    snarkjs.groth16.prove(pr(`${prefix}/batch_tree/4/${BATCH_TREE_CIRCUIT_FINAL(4)}`), witness),
  vkey_4: async () => await expVkey(pr(`${prefix}/batch_tree/4/${BATCH_TREE_CIRCUIT_FINAL(4)}`)),
  4: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/batch_tree/4/${BATCH_TREE_WASM(4)}`),
      pr(`${prefix}/batch_tree/4/${BATCH_TREE_WITNESS_CALCULATOR(4)}`),
      pr(`${prefix}/batch_tree/4/${BATCH_TREE_CIRCUIT_FINAL(4)}`)
    ),
  prove_8: async (witness) =>
    snarkjs.groth16.prove(pr(`${prefix}/batch_tree/8/${BATCH_TREE_CIRCUIT_FINAL(8)}`), witness),
  vkey_8: async () => await expVkey(pr(`${prefix}/batch_tree/8/${BATCH_TREE_CIRCUIT_FINAL(8)}`)),
  8: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/batch_tree/8/${BATCH_TREE_WASM(8)}`),
      pr(`${prefix}/batch_tree/8/${BATCH_TREE_WITNESS_CALCULATOR(8)}`),
      pr(`${prefix}/batch_tree/8/${BATCH_TREE_CIRCUIT_FINAL(8)}`)
    ),
  prove_16: async (witness) =>
    snarkjs.groth16.prove(pr(`${prefix}/batch_tree/16/${BATCH_TREE_CIRCUIT_FINAL(16)}`), witness),
  vkey_16: async () => await expVkey(pr(`${prefix}/batch_tree/16/${BATCH_TREE_CIRCUIT_FINAL(16)}`)),
  16: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/batch_tree/16/${BATCH_TREE_WASM(16)}`),
      pr(`${prefix}/batch_tree/16/${BATCH_TREE_WITNESS_CALCULATOR(16)}`),
      pr(`${prefix}/batch_tree/16/${BATCH_TREE_CIRCUIT_FINAL(16)}`)
    ),
  prove_32: async (witness) =>
    snarkjs.groth16.prove(pr(`${prefix}/batch_tree/32/${BATCH_TREE_CIRCUIT_FINAL(32)}`), witness),
  vkey_32: async () => await expVkey(pr(`${prefix}/batch_tree/32/${BATCH_TREE_CIRCUIT_FINAL(32)}`)),
  32: async () =>
    await fetchComponentsFromFilePaths(
      pr(`${prefix}/batch_tree/32/${BATCH_TREE_WASM(32)}`),
      pr(`${prefix}/batch_tree/32/${BATCH_TREE_WITNESS_CALCULATOR(32)}`),
      pr(`${prefix}/batch_tree/32/${BATCH_TREE_CIRCUIT_FINAL(32)}`)
    ),
});
