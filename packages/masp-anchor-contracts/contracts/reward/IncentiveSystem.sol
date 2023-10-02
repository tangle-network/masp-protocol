// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IIncentiveSystem.sol";
import "./IncentiveMetaController.sol";

contract IncentiveSystemWithToken is IIncentiveSystem {
	using SafeERC20 for IERC20;

	/// Constants
	uint256 public constant HourlyTarget = 1141; // 0.00001141 * 10^8, represented as fixed-point number
	uint256 public constant scaleFactor = 10 ** 8; // Scale factor for fixed-point arithmetic

	/// State Variables

	/// Proportional Gain
	/// - Role: Determines how strongly the system responds to the current error.
	/// - High Value: Results in a strong and immediate response to error but can cause the system to oscillate around the setpoint.
	/// - Low Value: Makes the system slow to respond to error and can result in steady-state error.
	uint256 public Kp = 1;

	/// Integral Gain
	/// - Role: Helps in eliminating the steady-state error by accumulating the past error.
	/// - High Value: Can cause the system to overshoot and oscillate.
	/// - Low Value: May not eliminate steady-state error quickly.
	uint256 public Ki = 0;

	/// Derivative Gain
	/// - Role: Responds to the rate of change of error, helping to dampen oscillations and overshoot.
	/// - High Value: Can make the system overly dampened and slow.
	/// - Low Value: May not prevent overshoot and oscillations.
	uint256 public Kd = 0;

	/// Reward rate
	uint256 public rewardRate;

	/// Last total supply of TNT
	uint256 public lastTotalSupply;

	/// Last amount of TNT minted by the incentive system
	uint256 public lastIncentiveMinted;

	/// Integral of error
	uint256 public integral;

	/// Last update time of the inflation rate
	uint256 public lastUpdateTime;

	/// Governance handler
	address public handler;

	/// PID meta-controller
	address public metaController;

	IERC20 public immutable TNT;

	/// Modifiers
	modifier onlyMetaControllerOrHandler() {
		require(
			msg.sender == handler || msg.sender == metaController,
			"Only meta-controller or handler can call this function"
		);
		_;
	}

	/// Constructor
	constructor(address _handler, address _TNT) {
		lastTotalSupply = getTotalSupply();
		lastIncentiveMinted = getIncentiveMinted();
		lastUpdateTime = block.timestamp;
		handler = _handler;
		IncentiveMetaController ctrl = new IncentiveMetaController(address(this), handler);
		metaController = address(ctrl);
		TNT = IERC20(_TNT);
	}

	/// Set the PID parameter Kp
	function setKp(uint256 _Kp) public onlyMetaControllerOrHandler {
		Kp = _Kp;
	}

	/// Set the PID parameter Ki
	function setKi(uint256 _Ki) public onlyMetaControllerOrHandler {
		Ki = _Ki;
	}

	/// Set the PID parameter Kd
	function setKd(uint256 _Kd) public onlyMetaControllerOrHandler {
		Kd = _Kd;
	}

	/// Get the total supply of TNT
	function getTotalSupply() public pure returns (uint256) {
		// Implement logic to get the total supply of TNT
		return 0;
	}

	/// Get the amount of TNT minted by the incentive system
	function getIncentiveMinted() public pure returns (uint256) {
		// Implement logic to get the amount of TNT minted by the incentive system
		return 0;
	}

	/// Get the hourly inflation rate
	function getHourlyInflation() public view returns (uint256) {
		uint256 currentTotalSupply = getTotalSupply();
		uint256 currentIncentiveMinted = getIncentiveMinted();
		return
			(((currentTotalSupply - lastTotalSupply) -
				(currentIncentiveMinted - lastIncentiveMinted)) * scaleFactor) / lastTotalSupply;
	}

	/// Update the reward rate based on PID controller
	function updateRewardRate() public {
		// Ensure the function is called once per hour
		require(block.timestamp >= lastUpdateTime + 1 hours, "Can only update once per hour");

		// Calculate the actual hourly inflation rate
		uint256 currentTotalSupply = getTotalSupply();
		uint256 currentIncentiveMinted = getIncentiveMinted();
		uint256 actualHourlyInflation = getHourlyInflation();

		// Calculate the error
		int256 error = int256(HourlyTarget) - int256(actualHourlyInflation);

		// Calculate the elapsed time since the last update
		uint256 elapsedTime = block.timestamp - lastUpdateTime;

		// Update the integral of error
		integral += uint256(error) * elapsedTime;

		// Calculate the derivative of error
		int256 derivative = int256(
			(error - int256((HourlyTarget - actualHourlyInflation) * scaleFactor)) /
				int256(elapsedTime)
		);

		// Calculate the PID output
		int256 output = int256(Kp) *
			error +
			int256(Ki) *
			int256(integral) +
			int256(Kd) *
			derivative;

		// Adjust the reward rate based on the PID output
		rewardRate = uint256(int256(rewardRate) + output);

		// Update the state variables for the next iteration
		lastTotalSupply = currentTotalSupply;
		lastIncentiveMinted = currentIncentiveMinted;
		lastUpdateTime = block.timestamp;
	}
}
