// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IOracle } from "../../interfaces/IOracle.sol";

contract Oracle is IOracle {

    address public constant LIDO_ETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant ROCKET_ETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant MANTLE_ETH = 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f;

    function getPriceAndBalance(
        address _at,
        address _token
    ) external view returns(uint256, uint256) {
        if (_token == LIDO_ETH) return _stEth(_at);
        if (_token == ROCKET_ETH) return _stEth(_at);
        if (_token == MANTLE_ETH) return _stEth(_at);
        return (0, 0);
    }

    function getPrice(
        address _token
    ) external view returns(uint256) {
        if (_token == LIDO_ETH) return _stEth();
        if (_token == ROCKET_ETH) return _rEthPrice();
        if (_token == MANTLE_ETH) return _mEth();
        return 0;
    }

    // function getTotalValue(
    //     address at,
    //     address[] calldata _tokens
    // ) external view returns (uint256 totalValue) {
    //     for (uint256 i = 0; i < _tokens.length;) {
    //         totalValue += 1e18;
    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    function _stEth() private pure returns (uint256) {
        return 1 ether;
    }

    function _rEthPrice() private view returns (uint256) {
        return rETH(ROCKET_ETH).getExchangeRate();
    }

    function _mEth() private view returns (uint256) {
        return mETH(MANTLE_ETH).mETHToETH(1 ether);
    }

    function _stEth(address _at) private view returns (uint256, uint256) {
        uint256 price = 1 ether;
        uint256 balance = IERC20(LIDO_ETH).balanceOf(_at);
        return (price, balance);
    }

    function _rEthPrice(address _at) private view returns (uint256, uint256) {
        uint256 price = rETH(ROCKET_ETH).getExchangeRate();
        uint256 balance = IERC20(ROCKET_ETH).balanceOf(_at);
        return (price, balance);
    }

    function _mEth(address _at) private view returns (uint256, uint256) {
        uint256 price = mETH(MANTLE_ETH).mETHToETH(1 ether);
        uint256 balance = IERC20(MANTLE_ETH).balanceOf(_at);
        return (price, balance);
    }
}

// solhint-disable-next-line
interface stETH {
    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
    function sharesOf(address _account) external view returns (uint256);
}
// solhint-disable-next-line
interface rETH {
    function getExchangeRate() external view returns (uint256);
    function getEthValue(uint256 _rethAmount) external view returns (uint256);
}
// solhint-disable-next-line
interface mETH {
    function ethToMETH(uint256 ethAmount) external view returns (uint256);
    function mETHToETH(uint256 mETHAmount) external view returns (uint256);
}