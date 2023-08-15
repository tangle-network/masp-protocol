<div align="center">
<a href="https://www.webb.tools/">

  ![Webb Logo](./.github/assets/webb_banner_light.png#gh-light-mode-only)
  ![Webb Logo](./.github/assets/webb_banner_dark.png#gh-dark-mode-only)
  </a>
</div>
<p align="left">
    <strong>Webb's Solidity Multi Asset Shielded Pool Protocol</strong>
</p>

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/webb-tools/masp-protocol/check.yml?branch=main&style=flat-square)](https://github.com/webb-tools/masp-protocol/actions) [![License Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=flat-square)](https://www.apache.org/licenses/LICENSE-2.0) [![Twitter](https://img.shields.io/twitter/follow/webbprotocol.svg?style=flat-square&label=Twitter&color=1DA1F2)](https://twitter.com/webbprotocol) [![Telegram](https://img.shields.io/badge/Telegram-gray?logo=telegram)](https://t.me/webbprotocol) [![Discord](https://img.shields.io/discord/833784453251596298.svg?style=flat-square&label=Discord&logo=discord)](https://discord.gg/cv8EfJu3Tn)


<!-- TABLE OF CONTENTS -->
<h2 id="table-of-contents" style=border:0!important> Table of Contents</h2>

<details open="open">
  <summary>Table of Contents</summary>
  <ul>
    <li><a href="#start"> Getting Started</a></li>
    <li><a href="#compile">Install and Compile</a></li>
    <li><a href="#test">Testing</a></li>
    <li><a href="#contribute">Contributing</a></li>
    <li><a href="#license">License</a></li>
  </ul>  
</details>

<h2 id="start"> Getting Started </h2>

The `masp-protocol` contains a `protocol-solidity` protocol extension for multi-asset shielded pools. Multi-asset shielded pools (MASP) are pools that shield multiple asset types under one pool system. This protocol currently supports both ERC20 fungible assets as well as non-fungible (NFT) assets. This protocol is built on top of the core `protocol-solidity` contracts by adding new functionality.

Other features of this MASP protocol are
- Shielded atomic swaps (SAS) between ERC20 and NFT assets.
- Delegatable proof generation for outsourcing heavy computation.
- Liquidity incentives for anonymity set growth.
- Viewing keys for compliance.
- Rollup functionality for batched deposits.
- (Coming soon) Fuzzy message detection over encrypted records.

For additional documentation on the MASP protocol, please refer to the [Webb MASP docs](https://docs.webb.tools/docs/protocols/masp/overview/).

For additional information on the base `protocol-solidity`, please refer to the [Webb protocol-solidity implementation docs](https://webb-tools.github.io/protocol-solidity/) and the official [Webb docs site](http://docs.webb.tools/). Have feedback on how to improve protocol-solidity? Or have a specific question to ask? Checkout the [Anchor System Feedback Discussion](https://github.com/webb-tools/feedback/discussions/categories/anchor-protocol).

<h2 id="compile"> Installation & Compile 💻 </h2>

Install dependencies: 

```
yarn install 
```

Update submodules:

```
git submodule update --init --recursive
```

Populate fixtures from the submodules:

```
yarn fetch:fixtures
```

To compile contracts and build typescript interfaces

```
yarn build
```

To run test suite:

```
yarn test
```

To fix the formatting, please run:

The installation takes around 3 minutes to be completed. When the command successfully finishes, it generates the circom binary in the directory `target/release`. You can install this binary as follows:
```
yarn format
```
The previous command will install the circom binary in the directory `$HOME/.cargo/bin`.

**Note:** If you push new fixtures to remote storage

snarkjs is a npm package that contains code to generate and validate ZK proofs from the artifacts produced by circom.

You can install snarkjs with the following command:
```
cd solidity-fixtures
dvc add solidity-fixtures
dvc push --remote aws
```

## Troubleshooting

[1] You may get following error while building on macBook if `gnu-sed` is not installed. Install it and add to your path as discussed [here](https://stackoverflow.com/questions/43696304/how-do-i-fix-sed-illegal-option-r-in-macos-sierra-android-build).
```bash
sed: 1: "packages/masp-anchor-co ...": extra characters at the end of p command
sed: 1: "packages/masp-anchor-co ...": extra characters at the end of p command
error Command failed with exit code 1.
```


<h2 id="contribute"> Contributing </h2>

If you have a contribution in mind, please check out our [Contribution Guide](./.github/CONTRIBUTING.md) for information on how to do so. We are excited for your first contribution!

<h2 id="license"> License </h2>

Licensed under <a href="LICENSE">Apache 2.0 / MIT license</a>.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in this crate by you, as defined in the MIT OR Apache 2.0 license, shall be licensed as above, without any additional terms or conditions.
