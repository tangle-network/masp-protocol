// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IOracle, Configuration, WhitelistedTokens } from "./Configuration.sol";
import { PRECISION, FEE_BASIS_POINTS } from  "./OmniLib.sol";
import { IOmniPool } from "../../interfaces/IOmniPool.sol";
import { ERC20, IERC20 } from "./ERC20.sol";
import { SafeERC20 } from  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract OmniPool is Configuration, ERC20, ReentrancyGuard, IOmniPool {
    using SafeERC20 for IERC20;

    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        uint256 _feeCap
    )
    ERC20(_name, _symbol)
    Configuration(_oracle, _feeCap) {}

    function deposit(
        address _token,
        uint256 _amount
    ) external nonReentrant returns (uint256 shares) {
        shares = _deposit(_token, _amount);
        _mint(msg.sender, shares);
    }

     function depositBatch(
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external nonReentrant returns (uint256 shares) {
        // validate arrays lengths
        if (_tokens.length != _amounts.length) revert ArgumentsLengthMismatch();

        for (uint256 i = 0; i < _tokens.length;) {
            // process deposit and accumulate shares
            unchecked {
                shares += _deposit(_tokens[i], _amounts[i]);
                ++i;
            }
        }
        // mint accumulated shares at once
        _mint(msg.sender, shares);
    }

    function withdraw(
        address _token,
        uint256 _shares
    ) external nonReentrant returns (uint256 amount) {
        // validate token whitelists and shares are not zero
        if(_shares == 0) revert WithdrawAmountIsZero();
        if(!_whitelist.exists(_token)) revert TokenIsNotWhitelisted(_token);

        // calculate value of shares to withdraw
        uint256 withdrawValue = _shares * totalPoolValue() / totalSupply;
        // calculate amount of token to withdraw
        amount = withdrawValue * PRECISION / oracle.getPrice(_token);
        // burn shares
        _burn(msg.sender, _shares);
        // withdraw tokens
        IERC20(_token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, _token, amount, _shares);
    }

    function swap(
        address _in,
        address _out,
        uint256 _amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        // validate amountIn is non zero
        if(_amountIn == 0) revert SwapAmountIsZero();

        // validate tokens are whitelisted
        if(!_whitelist.exists(_in)) revert TokenIsNotWhitelisted(_in);
        if(!_whitelist.exists(_out)) revert TokenIsNotWhitelisted(_out);

        amountOut = _calculateAmountOut(_in, _out, _amountIn);

        IERC20(_out).safeTransferFrom(address(this), msg.sender, amountOut);

        emit Swap(msg.sender, _in, _out, _amountIn, amountOut);
    }

    function totalPoolValue() public view returns (uint256 value) {
        uint256 length = _whitelist.array.length;
        for (uint256 i = 0; i < length;) {
            (uint256 price, uint256 balance) = oracle.getPriceAndBalance(address(this), _whitelist.array[i]);
            unchecked {
                value += (price * balance) / PRECISION;
                ++i;
            }
        }
    }

    function _deposit(
        address _token,
        uint256 _amount
    ) private returns (uint256 shares) {
        // validate token whitelists and amount is not zero
        if(_amount == 0) revert DepositAmountIsZero();
        if(!_whitelist.exists(_token)) revert TokenIsNotWhitelisted(_token);

        // get native value of the deposit
        uint256 depositValue = oracle.getPrice(_token) * _amount / PRECISION;
        // calculate shares for the value
        shares = depositValue * totalSupply / totalPoolValue();

        // transfer deposit tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _token, _amount, shares);
    }

    function _calculateAmountOut(
        address _in,
        address _out,
        uint256 _amountIn
    ) private view returns (uint256 amountOut) {
        // read token prices and calculate ideal target value.
        uint256 priceIn = oracle.getPrice(_in);
        uint256 priceOut = oracle.getPrice(_out);

        // apply fees
        uint256 swapValueIn = _chargeFees(
            _calculateInputFee(_in),
            _amountIn * priceIn / PRECISION
        );
        uint256 swapValueOut = _chargeFees(
            _calculateOutputFee(_out),
            swapValueIn
        );

        // calculate output amount
        amountOut = swapValueOut * PRECISION / priceOut;
    }

    function _calculateInputFee(address _in) private view returns (uint256) {
        uint256 balance = IERC20(_in).balanceOf(address(this));
        uint256 target = _whitelist.allocationTargets[_in];
        if (balance <= target) return 0;
        uint256 proficit = balance - target;
        return proficit * FEE_BASIS_POINTS / target;
    }

    function _calculateOutputFee(address _out) private view returns (uint256) {
        uint256 balance = IERC20(_out).balanceOf(address(this));
        uint256 target = _whitelist.allocationTargets[_out];
        if (balance >= target) return 0;
        uint256 deficit = target - balance;
        return deficit * FEE_BASIS_POINTS / target;
    }

    function _chargeFees(uint256 _fee, uint256 _amount) private view returns (uint256){
        uint256 fee = _fee > feeCap ? feeCap : _fee;
        return _amount * fee / FEE_BASIS_POINTS;
    }

    function getWhitelistedTokens() external view returns (address[] memory whitelisted) {
        whitelisted = _whitelist.array;
    }

    function getTokenTargetAllocation(address _token) external view returns (uint256) {
        return _whitelist.allocationTargets[_token];
    }
}