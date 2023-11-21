import { BigNumberish } from 'ethers';

export type IMASPRewardExtData = {
  fee: BigNumberish;
  recipient: string;
  relayer: string;
};

export type IMASPRewardPublicInputs = {
  proof: string;
  rate: BigNumberish;
  anonymityRewardPoints: BigNumberish;
  rewardNullifier: BigNumberish;
  extDataHash: BigNumberish;
  whitelistedAssetIDs: number[];
  spentRoots: BigNumberish[];
  unspentRoots: BigNumberish[];
  extData: IMASPRewardExtData;
};

export type IMASPRewardAllInputs = {
  anonymityRewardPoints: BigNumberish;
  rewardNullifier: BigNumberish;
  extDataHash: BigNumberish;
  whitelistedAssetIDs: BigNumberish[];
  rates: number[];

  // MASP Spent Note for which anonymity points are being claimed
  noteChainID: BigNumberish;
  noteAmount: BigNumberish;
  noteAssetID: BigNumberish;
  noteTokenID: BigNumberish;
  note_ak_X: BigNumberish;
  note_ak_Y: BigNumberish;
  noteBlinding: BigNumberish;
  notePathIndices: BigNumberish;

  // inputs prefixed with spent, corresponds to the already spent UTXO
  spentTimestamp: BigNumberish;
  spentRoots: BigNumberish[];
  spentPathIndices: BigNumberish;
  spentPathElements: BigNumberish[];

  // inputs prefixed with unspent, corresponds to the unspent UTXO
  unspentTimestamp: BigNumberish;
  unspentRoots: BigNumberish[];
  unspentPathIndices: BigNumberish;
  unspentPathElements: BigNumberish[];

  selectedRewardRate: number;
};
