// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import { TokenInfo, PRECISION, FEE_BASIS_POINTS } from  "./OmniLib.sol";
import { IOmniPool } from "../../interfaces/IOmniPool.sol";
import { IOracle} from "../../interfaces/IOracle.sol";
import { ERC20 } from "./ERC20.sol";

contract OmniPool is IOmniPool, ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    address public immutable anchor;
    address public immutable treasury;
    IOracle public oracle;

    mapping(address => TokenInfo) private _tokenInfo;
    address[] private _whitelistedTokens;


    constructor(
        string memory _name,
        string memory _symbol,
        address _anchor,
        address _oracle,
        address _treasury
    ) ERC20(_name, _symbol) {
        anchor = _anchor;
        treasury = _treasury;
        oracle = IOracle(_oracle);
    }

    function changeOracle(
        address _newOracle
    ) external onlyOwner {

        address oldOracle = address(oracle);
        oracle = IOracle(_newOracle);

        emit OracleChanged(
            oldOracle,
            _newOracle
        );
    }

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
        // read token info
        TokenInfo info = _tokenInfo[_token];

        // validate token whitelists and shares are not zero
        if(!info.isWhitelisted()) revert TokenIsNotWhitelisted(_token);
        if(_shares == 0) revert WithdrawAmountIsZero();

        // get total pool value
        uint256 poolValue = totalPoolValue();
        // calculate value of shares to withdraw
        uint256 withdrawValue = _shares * totalSupply / poolValue;
        // calculate amount of token to withdraw
        amount = withdrawValue / oracle.getPrice(_token);
        // burn shares
        _burn(msg.sender, _shares);
        // withdraw tokens
        IERC20(_token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, _token, amount, _shares);
    }

    function swap(
        address _from,
        address _to,
        uint256 _amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        // read tokens info
        TokenInfo tokenIn = _tokenInfo[_from];
        TokenInfo tokenOut = _tokenInfo[_to];

        // validate tokens are whitelisted
        if(!tokenIn.isWhitelisted()) revert TokenIsNotWhitelisted(_from);
        if(!tokenOut.isWhitelisted()) revert TokenIsNotWhitelisted(_to);
        // validate amountIn is non zero
        if(_amountIn == 0) revert SwapAmountIsZero();

       
        uint256 swapValueIn = _chargeFees(tokenIn, _amountIn * oracle.getPrice(_from) / PRECISION);
        uint256 swapValueOut = _chargeFees(tokenOut, swapValueIn);
        amountOut = swapValueOut * PRECISION / oracle.getPrice(_to);

        uint256 sharesToBurn = swapValueOut * totalSupply / totalPoolValue();

        if (IERC20(_to).balanceOf(address(this)) >= amountOut) revert NotEnoughTokensToWithdraw();

        IERC20(_to).safeTransferFrom(address(this), msg.sender, amountOut);

        _burn(msg.sender, sharesToBurn);

        emit Withdraw(msg.sender, _to, amountOut, sharesToBurn);
    }

    function totalPoolValue() public view returns (uint256 value) {
        uint256 length = _whitelistedTokens.length;
        for (uint256 i = 0; i < length;) {
            (uint256 price, uint256 balance) =oracle.getPriceAndBalance(address(this), _whitelistedTokens[i]);
            value += (price * balance) / PRECISION;
            unchecked {
                ++i;
            }
        }
    }

    function getWhitelistedTokens() public view returns (address[] memory whitelisted) {
        whitelisted = _whitelistedTokens;
    }

    function _deposit(
        address _token,
        uint256 _amount
    ) private returns (uint256 shares) {
        // read token info
        TokenInfo info = _tokenInfo[_token];

        // validate token whitelists and amount is not zero
        if(!info.isWhitelisted()) revert TokenIsNotWhitelisted(_token);
        if(_amount == 0) revert DepositAmountIsZero();

        // get native value of the deposit
        uint256 depositValue = oracle.getPrice(_token) * _amount / PRECISION;
        // calculate shares for the value
        shares = depositValue * totalSupply / totalPoolValue();

        // transfer deposit tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _token, _amount, shares);
    }

    function _chargeFees(TokenInfo _info, uint256 _amount) private returns (uint256){
        // fee logic here
    }
}