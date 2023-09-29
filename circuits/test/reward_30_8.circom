pragma circom 2.0.0;

include "../masp-vanchor/reward.circom";

component main { public [anonymityRewardPoints, rewardNullifier, whitelistedAssetIDs, rates, extDataHash, spentRoots, unspentRoots] } = Reward(30, 21663839004416932945382355908790599225266501822907911457504978515578255421292, 8, 10);