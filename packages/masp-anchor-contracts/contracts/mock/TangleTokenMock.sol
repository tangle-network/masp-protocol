/**
 * Copyright 2021-2023 Webb Technologies
 * SPDX-License-Identifier: MIT OR Apache-2.0
 */

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TangleTokenMockFixedSupply is ERC20 {
	constructor() ERC20("Tangle Mock Token", "TNT-MOCK") {
		// Mint 1 billion tokens to the contract deployer
		uint256 initialSupply = 1_000_000_000 * (10 ** uint256(decimals()));
		_mint(msg.sender, initialSupply);
	}
}
