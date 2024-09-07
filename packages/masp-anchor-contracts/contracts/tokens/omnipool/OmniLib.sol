// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

type TokenInfo is uint256;

using OmniLib for TokenInfo global;

library OmniLib {

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