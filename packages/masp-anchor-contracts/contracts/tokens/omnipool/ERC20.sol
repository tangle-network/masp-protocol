// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract ERC20 is IERC20 {

    error TransferAmountExceedsBalance();
    error TransferAmountExceedsAllowance();
    error BurnAmountExceedsBalance();
    error InsufficientAllowance();

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    uint256 public totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return _balances[_account];
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool) {
        uint256 currentAllowance = _allowances[_from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < _amount) revert InsufficientAllowance();
            unchecked {
                _approve(_from, msg.sender, currentAllowance - _amount);
            }
        }
        _transfer(_from, _to, _amount);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _amount) internal {
        uint256 fromBalance = _balances[_from];
        if (fromBalance < _amount) revert TransferAmountExceedsBalance();

        unchecked {
            _balances[_from] = fromBalance - _amount;
            _balances[_to] += _amount;
        }

        emit Transfer(_from, _to, _amount);
    }

    function _mint(address _account, uint256 _amount) internal {
        totalSupply += _amount;
        unchecked {
            _balances[_account] += _amount;
        }

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        uint256 accountBalance = _balances[_account];

        if (accountBalance < _amount) revert BurnAmountExceedsBalance();
        unchecked {
            _balances[_account] = accountBalance - _amount;
            totalSupply -= _amount;
        }

        emit Transfer(_account, address(0), _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

}