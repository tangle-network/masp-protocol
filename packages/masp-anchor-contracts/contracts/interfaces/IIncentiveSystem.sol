// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IIncentiveSystem {
	function getHourlyInflation() external view returns (uint256);

	function setKp(uint256 _Kp) external;

	function setKi(uint256 _Ki) external;

	function setKd(uint256 _Kd) external;

	function Kp() external view returns (uint256);

	function Ki() external view returns (uint256);

	function Kd() external view returns (uint256);

	function HourlyTarget() external view returns (uint256);
}
