import { ethers, assert } from 'hardhat';
import { HARDHAT_ACCOUNTS } from '../../hardhatAccounts.js';

import {
  DeterministicDeployFactory__factory,
  ERC20PresetMinterPauser,
  ERC20PresetMinterPauser__factory,
  VAnchorEncodeInputs__factory,
} from '@webb-tools/contracts';

import { getChainIdType } from '@webb-tools/utils';
import { PoseidonHasher, VAnchor } from '@webb-tools/anchors';
import { Deployer } from '@webb-tools/create2-utils';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Verifier } from '@webb-tools/anchors';
import { startGanacheServer } from '../startGanache';
import {
  MultiAssetVerifier,
  Registry,
  RegistryHandler,
  MultiFungibleTokenManager,
  MultiNftTokenManager,
  MultiAssetVAnchorProxy,
  SwapProofVerifier,
  ProxiedBatchTree,
  BatchTreeVerifier,
  MultiAssetVAnchorBatchTree,
} from '@webb-tools/masp-anchors';
import {
  RewardSwap,
  RewardManager,
  RewardProofVerifier
} from '@webb-tools/masp-reward';
import {
  maspSwapFixtures,
  maspVAnchorFixtures,
  maspRewardFixtures,
  batchTreeFixtures,
} from '@webb-tools/protocol-solidity-extension-utils';

const maspVAnchorZkComponents = maspVAnchorFixtures('../../../solidity-fixtures/solidity-fixtures');
const maspSwapZkComponents = maspSwapFixtures('../../../solidity-fixtures/solidity-fixtures');
const maspRewardZkComponents = maspRewardFixtures('../../../solidity-fixtures/solidity-fixtures');
const batchTreeZkComponents = batchTreeFixtures('../../../solidity-fixtures/solidity-fixtures');

describe('Should deploy MASP contracts to the same address', () => {
  let deployer1: Deployer;
  let deployer2: Deployer;
  let token1: ERC20PresetMinterPauser;
  let token2: ERC20PresetMinterPauser;
  let poseidonHasher1: PoseidonHasher;
  let poseidonHasher2: PoseidonHasher;
  let sender: SignerWithAddress;
  const FIRST_CHAIN_ID = 31337;
  const SECOND_CHAIN_ID = 10000;
  let ganacheServer2: any;
  let ganacheProvider2 = new ethers.providers.JsonRpcProvider(
    `http://localhost:${SECOND_CHAIN_ID}`
  );
  ganacheProvider2.pollingInterval = 1;
  let ganacheWallet1 = new ethers.Wallet(HARDHAT_ACCOUNTS[1].privateKey, ganacheProvider2);
  let ganacheWallet2 = new ethers.Wallet(
    'c0d375903fd6f6ad3edafc2c5428900c0757ce1da10e5dd864fe387b32b91d7e',
    ganacheProvider2
  );

  const salt = '666';
  const saltHex = ethers.utils.id(salt);

  before('setup networks', async () => {
    ganacheServer2 = await startGanacheServer(
      SECOND_CHAIN_ID,
      SECOND_CHAIN_ID,
      [
        {
          balance: '0x1000000000000000000000',
          secretKey: '0xc0d375903fd6f6ad3edafc2c5428900c0757ce1da10e5dd864fe387b32b91d7e',
        },
        {
          balance: '0x1000000000000000000000',
          secretKey: '0x' + HARDHAT_ACCOUNTS[1].privateKey,
        },
      ],
      {
        chain: {
          allowUnlimitedContractSize: true,
          allowUnlimitedInitCodeSize: true,
        },
      }
    );
    const signers = await ethers.getSigners();
    const wallet = signers[1];
    let hardhatNonce = await wallet.provider.getTransactionCount(wallet.address, 'latest');
    let ganacheNonce = await ganacheWallet1.provider.getTransactionCount(
      ganacheWallet1.address,
      'latest'
    );
    assert(ganacheNonce <= hardhatNonce);
    while (ganacheNonce < hardhatNonce) {
      ganacheWallet1.sendTransaction({
        to: ganacheWallet2.address,
        value: ethers.utils.parseEther('0.0'),
      });
      hardhatNonce = await wallet.provider.getTransactionCount(wallet.address, 'latest');
      ganacheNonce = await ganacheWallet1.provider.getTransactionCount(
        ganacheWallet1.address,
        'latest'
      );
    }
    assert.strictEqual(ganacheNonce, hardhatNonce);
    sender = wallet;

    while (ganacheNonce !== hardhatNonce) {
      if (ganacheNonce < hardhatNonce) {
        const Deployer2 = new DeterministicDeployFactory__factory(ganacheWallet1);
        let deployer2 = await Deployer2.deploy();
        await deployer2.deployed();
      } else {
        const Deployer1 = new DeterministicDeployFactory__factory(sender);
        let deployer1 = await Deployer1.deploy();
        await deployer1.deployed();
      }

      hardhatNonce = await sender.provider.getTransactionCount(sender.address, 'latest');
      ganacheNonce = await ganacheWallet1.provider.getTransactionCount(
        ganacheWallet1.address,
        'latest'
      );
      if (ganacheNonce === hardhatNonce) {
        break;
      }
    }
    assert.strictEqual(ganacheNonce, hardhatNonce);
    const Deployer1 = new DeterministicDeployFactory__factory(sender);
    let deployer1Contract = await Deployer1.deploy();
    await deployer1Contract.deployed();
    deployer1 = new Deployer(deployer1Contract);

    const Deployer2 = new DeterministicDeployFactory__factory(ganacheWallet1);
    let deployer2Contract = await Deployer2.deploy();
    await deployer2Contract.deployed();
    deployer2 = new Deployer(deployer2Contract);
    assert.strictEqual(deployer1.address, deployer2.address);
  });

  describe('#deploy common', () => {
    it('should deploy ERC20PresetMinterPauser to the same address using different wallets', async () => {
      const argTypes = ['string', 'string'];
      const args = ['test token', 'TEST'];
      const { contract: contractToken1 } = await deployer1.deploy(
        ERC20PresetMinterPauser__factory,
        saltHex,
        sender,
        undefined,
        argTypes,
        args
      );
      token1 = contractToken1;
      const { contract: contractToken2 } = await deployer2.deploy(
        ERC20PresetMinterPauser__factory,
        saltHex,
        ganacheWallet2,
        undefined,
        argTypes,
        args
      );
      token2 = contractToken2;
      assert.strictEqual(token1.address, token2.address);
    });
    it('should deploy VAnchorEncodeInput library to the same address using same handler', async () => {
      const { contract: contract1 } = await deployer1.deploy(
        VAnchorEncodeInputs__factory,
        saltHex,
        sender
      );
      const { contract: contract2 } = await deployer2.deploy(
        VAnchorEncodeInputs__factory,
        saltHex,
        ganacheWallet2
      );
      assert.strictEqual(contract1.address, contract2.address);
    });
    it('should deploy poseidonHasher to the same address using different wallets', async () => {
      poseidonHasher1 = await PoseidonHasher.create2PoseidonHasher(deployer1, salt, sender);
      poseidonHasher2 = await PoseidonHasher.create2PoseidonHasher(deployer2, salt, ganacheWallet2);
      assert.strictEqual(poseidonHasher1.contract.address, poseidonHasher2.contract.address);
    });
  });
  describe('#deploy MASP VAnchor', () => {
    let maspVanchorVerifier1: MultiAssetVerifier;
    let maspVanchorVerifier2: MultiAssetVerifier;
    let swapVerifier1: SwapProofVerifier;
    let swapVerifier2: SwapProofVerifier;
    let registry1: Registry;
    let registry2: Registry;
    let registryHandler1: RegistryHandler;
    let registryHandler2: RegistryHandler;
    let multiFungibleTokenManager1: MultiFungibleTokenManager;
    let multiFungibleTokenManager2: MultiFungibleTokenManager;
    let multiNftTokenManager1: MultiNftTokenManager;
    let multiNftTokenManager2: MultiNftTokenManager;
    let batchTreeVerifier1: BatchTreeVerifier;
    let batchTreeVerifier2: BatchTreeVerifier;
    let depositTree1: ProxiedBatchTree;
    let depositTree2: ProxiedBatchTree;
    let unspentTree1: ProxiedBatchTree;
    let unspentTree2: ProxiedBatchTree;
    let spentTree1: ProxiedBatchTree;
    let spentTree2: ProxiedBatchTree;
    let maspProxy1: MultiAssetVAnchorProxy;
    let maspProxy2: MultiAssetVAnchorProxy;

    it('should deploy verifiers to the same address using different wallets', async () => {
      assert.strictEqual(deployer1.address, deployer2.address);
      maspVanchorVerifier1 = await Verifier.create2Verifier(deployer1, salt, sender);
      maspVanchorVerifier2 = await Verifier.create2Verifier(deployer2, salt, ganacheWallet2);
      assert.strictEqual(
        maspVanchorVerifier1.contract.address,
        maspVanchorVerifier2.contract.address
      );
      let two1 = await SwapProofVerifier.create2Verifiers(deployer1, saltHex, sender);
      let two2 = await SwapProofVerifier.create2Verifiers(deployer2, saltHex, ganacheWallet2);
      swapVerifier1 = await SwapProofVerifier.create2SwapProofVerifier(
        deployer1,
        saltHex,
        sender,
        two1.v2,
        two1.v8
      );
      swapVerifier2 = await SwapProofVerifier.create2SwapProofVerifier(
        deployer2,
        saltHex,
        ganacheWallet2,
        two2.v2,
        two2.v8
      );

      assert.strictEqual(swapVerifier1.contract.address, swapVerifier2.contract.address);
    });

    it('should deploy MultiFungibleTokenManager to the same address using different wallets', async () => {
      multiFungibleTokenManager1 = await MultiFungibleTokenManager.create2MultiFungibleTokenManager(
        deployer1,
        saltHex,
        sender
      );
      multiFungibleTokenManager2 = await MultiFungibleTokenManager.create2MultiFungibleTokenManager(
        deployer2,
        saltHex,
        ganacheWallet2
      );
      assert.strictEqual(
        multiFungibleTokenManager1.contract.address,
        multiFungibleTokenManager2.contract.address
      );
    });

    it('should deploy the MultiNftTokenManager to the same address using different wallets', async () => {
      multiNftTokenManager1 = await MultiNftTokenManager.create2MultiNftTokenManager(
        deployer1,
        saltHex,
        sender
      );
      multiNftTokenManager2 = await MultiNftTokenManager.create2MultiNftTokenManager(
        deployer2,
        saltHex,
        ganacheWallet2
      );
      assert.strictEqual(
        multiNftTokenManager1.contract.address,
        multiNftTokenManager2.contract.address
      );
    });

    it('should deploy the MaspProxy to the same address using different wallets', async () => {
      maspProxy1 = await MultiAssetVAnchorProxy.create2MultiAssetVAnchorProxy(
        deployer1,
        saltHex,
        poseidonHasher1.contract.address,
        sender
      );
      maspProxy2 = await MultiAssetVAnchorProxy.create2MultiAssetVAnchorProxy(
        deployer2,
        saltHex,
        poseidonHasher2.contract.address,
        ganacheWallet2
      );
      assert.strictEqual(maspProxy1.contract.address, maspProxy2.contract.address);
    });

    it('should deploy the registry to the same address using different wallets', async () => {
      registry1 = await Registry.create2Registry(deployer1, saltHex, sender);
      registry2 = await Registry.create2Registry(deployer2, saltHex, ganacheWallet2);
      assert.strictEqual(registry1.contract.address, registry2.contract.address);

      let dummyBridgeSigner = (await ethers.getSigners())[4];
      let dummyBridgeAddress = await dummyBridgeSigner.getAddress();
      registryHandler1 = await RegistryHandler.create2RegistryHandler(
        dummyBridgeAddress,
        [],
        [],
        deployer1,
        saltHex,
        sender
      );
      registryHandler2 = await RegistryHandler.create2RegistryHandler(
        dummyBridgeAddress,
        [],
        [],
        deployer2,
        saltHex,
        ganacheWallet2
      );
      assert.strictEqual(registryHandler1.contract.address, registryHandler2.contract.address);
    });

    it('should deploy batch verifiers to the same address using different wallets', async () => {
      batchTreeVerifier1 = await BatchTreeVerifier.create2BatchTreeVerifier(
        deployer1,
        saltHex,
        sender
      );
      batchTreeVerifier2 = await BatchTreeVerifier.create2BatchTreeVerifier(
        deployer2,
        saltHex,
        ganacheWallet2
      );
      assert.strictEqual(batchTreeVerifier1.contract.address, batchTreeVerifier2.contract.address);
    });

    it('should deploy the proxied batch tree to the same address using different wallets', async () => {
      const levels = 30;
      let batchTreeZkComponents_4 = await batchTreeZkComponents[4]();
      let batchTreeZkComponents_8 = await batchTreeZkComponents[8]();
      let batchTreeZkComponents_16 = await batchTreeZkComponents[16]();
      let batchTreeZkComponents_32 = await batchTreeZkComponents[32]();

      depositTree1 = await ProxiedBatchTree.create2ProxiedBatchTree(
        deployer1,
        saltHex,
        batchTreeVerifier1.contract.address,
        levels,
        poseidonHasher1.contract.address,
        maspProxy1.contract.address,
        batchTreeZkComponents_4,
        batchTreeZkComponents_8,
        batchTreeZkComponents_16,
        batchTreeZkComponents_32,
        sender
      );
      depositTree2 = await ProxiedBatchTree.create2ProxiedBatchTree(
        deployer2,
        saltHex,
        batchTreeVerifier2.contract.address,
        levels,
        poseidonHasher2.contract.address,
        maspProxy2.contract.address,
        batchTreeZkComponents_4,
        batchTreeZkComponents_8,
        batchTreeZkComponents_16,
        batchTreeZkComponents_32,
        ganacheWallet2
      );
      assert.strictEqual(depositTree1.contract.address, depositTree2.contract.address);

      spentTree1 = await ProxiedBatchTree.create2ProxiedBatchTree(
        deployer1,
        ethers.utils.id('667'),
        batchTreeVerifier1.contract.address,
        levels,
        poseidonHasher1.contract.address,
        maspProxy1.contract.address,
        batchTreeZkComponents_4,
        batchTreeZkComponents_8,
        batchTreeZkComponents_16,
        batchTreeZkComponents_32,
        sender
      );

      spentTree2 = await ProxiedBatchTree.create2ProxiedBatchTree(
        deployer2,
        ethers.utils.id('667'),
        batchTreeVerifier2.contract.address,
        levels,
        poseidonHasher2.contract.address,
        maspProxy2.contract.address,
        batchTreeZkComponents_4,
        batchTreeZkComponents_8,
        batchTreeZkComponents_16,
        batchTreeZkComponents_32,
        ganacheWallet2
      );
      assert.strictEqual(spentTree1.contract.address, spentTree2.contract.address);

      unspentTree1 = await ProxiedBatchTree.create2ProxiedBatchTree(
        deployer1,
        ethers.utils.id('668'),
        batchTreeVerifier1.contract.address,
        levels,
        poseidonHasher1.contract.address,
        maspProxy1.contract.address,
        batchTreeZkComponents_4,
        batchTreeZkComponents_8,
        batchTreeZkComponents_16,
        batchTreeZkComponents_32,
        sender
      );

      unspentTree2 = await ProxiedBatchTree.create2ProxiedBatchTree(
        deployer2,
        ethers.utils.id('668'),
        batchTreeVerifier2.contract.address,
        levels,
        poseidonHasher2.contract.address,
        maspProxy2.contract.address,
        batchTreeZkComponents_4,
        batchTreeZkComponents_8,
        batchTreeZkComponents_16,
        batchTreeZkComponents_32,
        ganacheWallet2
      );
      assert.strictEqual(unspentTree1.contract.address, unspentTree2.contract.address);
    });

    it.skip('should deploy VAnchor to the same address using different wallets (but same handler) ((note it needs previous test to have run))', async () => {
      const levels = 30;
      assert.strictEqual(
        maspVanchorVerifier1.contract.address,
        maspVanchorVerifier2.contract.address
      );
      assert.strictEqual(poseidonHasher1.contract.address, poseidonHasher2.contract.address);
      assert.strictEqual(token1.address, token2.address);
      assert.strictEqual(swapVerifier1.contract.address, swapVerifier2.contract.address);
      let dummyHandlerAddress = await (await ethers.getSigners())[5].getAddress();
      let zkComponents2_2 = await maspVAnchorZkComponents[22]();
      let zkComponents16_2 = await maspVAnchorZkComponents[162]();
      let swapCircuitZkComponents = await maspSwapZkComponents[230]();

      const vanchor1 = await MultiAssetVAnchorBatchTree.create2MultiAssetVAnchorBatchTree(
        deployer1,
        saltHex,
        registry1.contract.address,
        maspVanchorVerifier1.contract.address,
        batchTreeVerifier1.contract.address,
        swapVerifier1.contract.address,
        dummyHandlerAddress,
        poseidonHasher1.contract.address,
        maspProxy1.contract.address,
        levels,
        1,
        zkComponents2_2,
        zkComponents16_2,
        swapCircuitZkComponents,
        depositTree1,
        spentTree1,
        unspentTree1,
        sender
      );
      const vanchor2 = await MultiAssetVAnchorBatchTree.create2MultiAssetVAnchorBatchTree(
        deployer2,
        saltHex,
        registry2.contract.address,
        maspVanchorVerifier2.contract.address,
        batchTreeVerifier2.contract.address,
        swapVerifier2.contract.address,
        dummyHandlerAddress,
        poseidonHasher2.contract.address,
        maspProxy2.contract.address,
        levels,
        1,
        zkComponents2_2,
        zkComponents16_2,
        swapCircuitZkComponents,
        depositTree2,
        spentTree2,
        unspentTree2,
        ganacheWallet2
      );
      assert.strictEqual(vanchor1.contract.address, vanchor2.contract.address);
    });
  });
  describe('deploy MASP Reward', () => {
    let rewardVerifier1: RewardProofVerifier;
    let rewardVerifier2: RewardProofVerifier;
    it('should deploy Reward proof Verifiers to the same address using different wallets', async () => {
      // deploy reward verifiers
      rewardVerifier1 = await RewardProofVerifier.create2RewardProofVerifier(
        deployer1,
        saltHex,
        sender,
      );
      rewardVerifier2 = await RewardProofVerifier.create2RewardProofVerifier(
        deployer2,
        saltHex,
        ganacheWallet2,
      );
      assert.strictEqual(rewardVerifier1.contract.address, rewardVerifier2.contract.address);
    });
    it('should deploy RewardManager to the same address', async () => {
      rewardVerifier1 = await RewardProofVerifier.create2RewardProofVerifier(
        deployer1,
        saltHex,
        sender,
      );
      let rewardCircuitZkComponents = await maspRewardZkComponents[230]();
      let maxEdges = 2;
      let rate = 1;
      let initialWhitelistedAssetIds = [1, 2, 3, 4, 5, 6, 7, 8];

      let rewardSwapContractExpectedAddress = await RewardSwap.getExpectedCreate2Address(deployer1.address, saltHex);

      // create a new reward manager
      const rewardManager1 = await RewardManager.create2RewardManager(
        deployer1,
        sender,
        saltHex,
        rewardSwapContractExpectedAddress,
        rewardVerifier1,
        sender.address,
        rewardCircuitZkComponents,
        maxEdges,
        rate,
        initialWhitelistedAssetIds
      );

      // create another reward manager
      const rewardManager2 = await RewardManager.create2RewardManager(
        deployer2,
        sender,
        saltHex,
        rewardSwapContractExpectedAddress,
        rewardVerifier1,
        sender.address,
        rewardCircuitZkComponents,
        maxEdges,
        rate,
        initialWhitelistedAssetIds
      );

      assert.strictEqual(rewardManager1.contract.address, rewardManager2.contract.address);
    });
  });
  after('terminate networks', async () => {
    await ganacheServer2.close();
  });
});
