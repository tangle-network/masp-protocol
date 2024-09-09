// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IOracle, Configuration, WhitelistedTokens } from "./Configuration.sol";
import { PRECISION, FEE_BASIS_POINTS, FeeConfig, Deposits } from  "./OmniLib.sol";
import { ERC20, IERC20 } from "./ERC20.sol";
import { IOmniPool } from "../../interfaces/IOmniPool.sol";
import { SafeERC20 } from  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract OmniPool is Configuration, ERC20, ReentrancyGuard, IOmniPool {
    using SafeERC20 for IERC20;

    mapping(address => Deposits) private _userDeposits;

    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _treasury,
        uint256 _feeCap,
        uint256 _protocolFee
    )
    ERC20(_name, _symbol)
    Configuration(_oracle, _treasury, _feeCap, _protocolFee) {}

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
       if (_shares == 0) revert WithdrawAmountIsZero();
       if (!_whitelist.exists(_token)) revert TokenIsNotWhitelisted(_token);

        // burn shares
        _burn(msg.sender, _shares);
        // calculate value of shares
        uint256 withdrawValue = _shares * _totalPoolValue() / totalSupply;
        // calculate amount of token to withdraw
        amount = withdrawValue * PRECISION / oracle.getPrice(_token);
        // check that user deposit can sustain the whole withdrawal
        amount = _processDepositRecords(_userDeposits[msg.sender], _token, amount, withdrawValue);
        
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
       if (_amountIn == 0) revert SwapAmountIsZero();

        // validate tokens are whitelisted
       if (!_whitelist.exists(_in)) revert TokenIsNotWhitelisted(_in);
       if (!_whitelist.exists(_out)) revert TokenIsNotWhitelisted(_out);

        IERC20(_out).safeTransferFrom(msg.sender, address(this), _amountIn);

        amountOut = _chargeFeesAndCalculateAmountOut(_in, _out, _amountIn);

        IERC20(_out).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, _in, _out, _amountIn, amountOut);
    }
    
    /**
        @custom:callstack withdraw external function.
        @custom:callstack deposit external function => _deposit private function.
    */
    function _totalPoolValue() private view returns (uint256 value) {
        uint256 length = _whitelist.array.length;
        for (uint256 i = 0; i < length;) {
            (uint256 price, uint256 balance) = oracle.getPriceAndBalance(address(this), _whitelist.array[i]);
            unchecked {
                value += (price * balance) / PRECISION;
                ++i;
            }
        }
    }

    /**
        @custom:callstack deposit external function.
        @custom:callstack depositBatch external function.
    */
    function _deposit(
        address _token,
        uint256 _amount
    ) private returns (uint256 shares) {
        // TODO GAS-GOLFING: combine oracle calls into one
        // validate token whitelists and amount is not zero
       if (_amount == 0) revert DepositAmountIsZero();
       if (!_whitelist.exists(_token)) revert TokenIsNotWhitelisted(_token);

        // get native value of the deposit
        uint256 depositValue = oracle.getPrice(_token) * _amount / PRECISION;
        // get amount of the deposit
        uint256 depositAmount = oracle.getDepositAmount(_token, _amount);
        // calculate shares for the value
        shares = depositValue * totalSupply / _totalPoolValue();

        // transfer deposit tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        // add deposit record
        _userDeposits[msg.sender].add(_token, depositAmount);

        emit Deposit(msg.sender, _token, _amount, shares);
    }

    /**
        @custom:callstack withdraw external function.
    */
    function _processDepositRecords(
        Deposits storage _deposits,
        address _token,
        uint256 _amount,
        uint256 _value
    ) private returns (uint256 amount) {
        // read deposited amount of underlying token.
        uint256 depositAmount = oracle.getDepositAmount(_token, _amount);
        // check if user deposit can sustain the whole withdrawal
        uint256 uncoveredDeposit = _deposits.remove(_token, depositAmount);
        // return if deposit covered withdrawal
        if (uncoveredDeposit == 0) return _amount;

        // read fee config
        FeeConfig config = _feeConfig;
        // cover value with user's other deposits
        uint256 uncoveredValue = _value * uncoveredDeposit  / depositAmount;
        for (;;) {
            // find the most appropriate deposit to fulfill uncovered withdrawal
            address thisDepositToken = _findNextDeposit(_deposits);
            // read this deposit token price
            uint256 thisDepositPrice = oracle.getPrice(thisDepositToken);
            // calculate amount of next token, which will fulfill uncovered withdrawal
            uint256 thisTokenAmount = uncoveredValue * PRECISION / thisDepositPrice;
            // convert token amount to amount of underlying tokens
            uint256 thisDepositAmount = oracle.getDepositAmount(thisDepositToken, thisTokenAmount);
            // check if this deposit can cover withdrawal
            uint256 nextUncoveredDeposit = _deposits.remove(thisDepositToken, thisDepositAmount);
            // calculate amount of tokens of this deposit, which covered the withdrawal
            uint256 thisDepositTokensSpent = (thisDepositAmount - nextUncoveredDeposit) * thisTokenAmount / thisDepositAmount;
            // apply fee to this deposit
            thisDepositTokensSpent = _chargeFee(
                thisDepositToken,
                thisDepositTokensSpent,
                _calculateInputFee(thisDepositToken, config.feeCap()),
                config
            );
            uint256 thisDepositCoveredValue = thisDepositTokensSpent * thisDepositPrice / PRECISION;
            // store covered value in amount variable;
            amount += thisDepositCoveredValue;
            if (nextUncoveredDeposit == 0) break;
        }
        // convert covered value into output tokens
       amount = amount * _amount  / _value;
        // apply output fee to withdrawal amount
        amount = _chargeFee(
            _token,
            amount,
            _calculateOutputFee(_token, config.feeCap()),
            config
        );
    }

    /**
        @custom:callstack withdraw external function => _processDepositRecords private function.
    */
    function _findNextDeposit(Deposits storage _deposits) private view returns (address token) {
        // put user deposit tokens array length on the stack
        uint256 length = _deposits.tokens.length;
        // store highest disbalance index of token
        uint256 idx;
        // loop through tokens and find most suitable one
        for (uint256 i; i < length;) {
            (uint256 balance, uint256 target) = _getBalanceAndTarget(_deposits.tokens[i]);
            // if there is surplus token move to next
            if (target < balance) continue;
            // rewrite highest disbalance if its higher than previous
            idx = target - balance > idx ? i : idx;
            unchecked {
                ++i;
            }
        }
        // returns token with highest balance target difference
        token = _deposits.tokens[idx];
    }

    /**
        @custom:callstack swap external function.
    */
    function _chargeFeesAndCalculateAmountOut(
        address _in,
        address _out,
        uint256 _amountIn
    ) private returns (uint256 amountOut) {
        // TODO GAS-GOLFING: pre allocate memory for transfer calls and oracle calls.
        // read fee config
        FeeConfig config = _feeConfig;
        // calculate input and output fees in basis points
        uint256 inputFee = _calculateInputFee(_in, config.feeCap());
        uint256 outpuFee = _calculateOutputFee(_out, config.feeCap());
        // apply input fees and return amount after fee
        uint256 amountIn =  _chargeFee(_in, _amountIn, inputFee, config);
        // read token prices
        uint256 priceIn = oracle.getPrice(_in);
        uint256 priceOut = oracle.getPrice(_out);
        // calculate output amount and apply fee
        amountOut =  _chargeFee(_out, amountIn * priceIn / priceOut, outpuFee, config);
    }

    /**
        @custom:callstack swap external function => _processDepositRecords private function.
    */
    function _chargeFee(
        address _token,
        uint256 _amount,
        uint256 _fee,
        FeeConfig _config
    ) private returns (uint256) {
        uint256 feeAmount = _amount * _fee / FEE_BASIS_POINTS;
        uint256 protocolFeeAmount = feeAmount * _config.protocolFee() / FEE_BASIS_POINTS;
        if (protocolFeeAmount > 0) {
            IERC20(_token).safeTransfer(_config.treasury(), protocolFeeAmount);
        }
        return _amount - feeAmount;
    }

    /**
        @custom:callstack swap external function => _chargeFeesAndCalculateAmountOut private function.
    */
    function _calculateInputFee(address _in, uint256 cap) private view returns (uint256) {
        (uint256 balance, uint256 target) = _getBalanceAndTarget(_in);
        if (balance <= target) return 0;
        uint256 surplus = balance - target;
        uint256 fee = surplus * FEE_BASIS_POINTS / target;
        return fee > cap ? cap : fee;
    }

    /**
        @custom:callstack swap external function => _chargeFeesAndCalculateAmountOut private function.
        @custom:callstack withdraw external function => _updateDepositsRecordsAndCalculateAmount private function.
    */
    function _calculateOutputFee(address _out, uint256 cap) private view returns (uint256) {
        (uint256 balance, uint256 target) = _getBalanceAndTarget(_out);
        if (balance >= target) return 0;
        uint256 deficit = target - balance;
        uint256 fee = deficit * FEE_BASIS_POINTS / target;
        return fee > cap ? cap : fee;
    }

    function _getBalanceAndTarget(address _token) private view returns (uint256 balance, uint256 target) {
        balance = IERC20(_token).balanceOf(address(this));
        target = _whitelist.allocationTargets[_token];
        balance = oracle.getDepositAmount(_token, balance);
        target = oracle.getDepositAmount(_token, target);
    }

    function totalPoolValue() external view returns (uint256) {
        return _totalPoolValue();
    }

    function whitelistedTokens() external view returns (address[] memory whitelisted) {
        whitelisted = _whitelist.array;
    }

    function tokenTargetAllocation(address _token) external view returns (uint256) {
        return _whitelist.allocationTargets[_token];
    }

    function getFeeConfig() external view returns (uint256 feeCap_, uint256 protocolFee_, address treasury_) {
        FeeConfig config = _feeConfig;
        feeCap_ = config.feeCap();
        protocolFee_ = config.protocolFee();
        treasury_ = config.treasury();
    }

    function treasury() external view returns (address) {
        return _feeConfig.treasury();
    }

    function feeCap() external view returns (uint256) {
        return _feeConfig.feeCap();
    }

    function protocolFee() external view returns (uint256) {
        return _feeConfig.protocolFee();
    }
}