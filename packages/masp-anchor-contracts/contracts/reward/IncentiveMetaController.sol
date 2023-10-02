// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
pragma experimental ABIEncoderV2;

import "../interfaces/IIncentiveSystem.sol";

contract IncentiveMetaController {
	IIncentiveSystem public incentiveSystem;

	/// Constants for Adjustment Parameters
	uint256 public adjustmentInterval = 1 days;
	uint256 public lastAdjustmentTimestamp;

	uint256 constant MAX_ADJUSTMENT = 10; // Maximum 10% adjustment in one step

	/// Governance handler
	address public handler;

	/// Constructor
	constructor(address _incentiveSystem, address _handler) {
		incentiveSystem = IIncentiveSystem(_incentiveSystem);
		lastAdjustmentTimestamp = block.timestamp;
		handler = _handler;
	}

	function adjustPIDParameters() public {
		require(
			block.timestamp >= lastAdjustmentTimestamp + adjustmentInterval,
			"Adjustment interval not reached"
		);

		uint256 observedInflation = incentiveSystem.getHourlyInflation();
		uint256 targetInflation = incentiveSystem.HourlyTarget();

		// Calculate deviation
		int256 deviation = (int256(observedInflation - targetInflation) * 100) /
			int256(targetInflation);

		// Apply cap to deviation
		if (deviation > int256(MAX_ADJUSTMENT)) {
			deviation = int256(MAX_ADJUSTMENT);
		} else if (deviation < -int256(MAX_ADJUSTMENT)) {
			deviation = -int256(MAX_ADJUSTMENT);
		}

		// Adjust the PID parameters
		uint256 Kp_new = (incentiveSystem.Kp() * (100 + uint256(deviation))) / 100;
		uint256 Ki_new = (incentiveSystem.Ki() * (100 + uint256(deviation))) / 100;
		uint256 Kd_new = (incentiveSystem.Kd() * (100 + uint256(deviation))) / 100;

		incentiveSystem.setKp(Kp_new);
		incentiveSystem.setKi(Ki_new);
		incentiveSystem.setKd(Kd_new);

		lastAdjustmentTimestamp = block.timestamp;
	}

	// Function to manually adjust adjustmentInterval for flexibility
	function setAdjustmentInterval(uint256 _interval) external {
		adjustmentInterval = _interval;
	}
}
