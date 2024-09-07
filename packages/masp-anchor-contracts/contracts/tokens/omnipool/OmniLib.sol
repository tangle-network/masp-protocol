// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

type TokenInfo is uint256;

struct WhitelistedTokens {
    address[] array;
    mapping(address => uint256) idx;
}

using OmniLib for WhitelistedTokens global;
using OmniLib for TokenInfo global;

library OmniLib {

    function exists(WhitelistedTokens storage _whitelisted, address _token) internal view returns (bool) {
        return _whitelisted.idx[_token] != 0;
    }

    function add(WhitelistedTokens storage _whitelisted, address _token) internal {
        if (exists(_whitelisted, _token)) {
            return;
        }

        _whitelisted.array.push(_token);
        _whitelisted.idx[_token] = _whitelisted.array.length;
    }

    function remove(WhitelistedTokens storage _whitelisted, address _token) internal {
        uint256 tokenIdx = _whitelisted.idx[_token];

        if (tokenIdx == 0) {
            return;
        }

        uint256 arrayIdx = tokenIdx - 1;
        uint256 lastIdx = _whitelisted.array.length - 1;

        if (arrayIdx != lastIdx) {
            address lastElement = _whitelisted.array[lastIdx];
            _whitelisted.array[arrayIdx] = lastElement;
            _whitelisted.idx[lastElement] = tokenIdx;
        }

        _whitelisted.array.pop();
        delete _whitelisted.idx[_token];
    }

    function isWhitelisted(TokenInfo _info) internal pure returns (bool) {
        return uint128(TokenInfo.unwrap(_info)) == WHITELISTED;
    }
    
    function inputFee(TokenInfo _info) internal pure returns (uint256) {
        return TokenInfo.unwrap(_info) >> 192;
    }

    function outputFee(TokenInfo _info) internal pure returns (uint256) {
        return uint64(TokenInfo.unwrap(_info) >> 128);
    }

    function setFees(
        TokenInfo _info,
        uint256 _inputFee,
        uint256 _outputFee
    ) internal pure returns (TokenInfo) {
        return TokenInfo.wrap(
           _inputFee << 192 + _outputFee << 128 + uint128(TokenInfo.unwrap(_info))
        );
    }
}

uint256 constant PRECISION = 1e18;
uint256 constant FEE_BASIS_POINTS = 10_000;
uint256 constant WHITELISTED = 
    0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;