// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

type FeeConfig is uint256;

struct WhitelistedTokens {
    address[] array;
    mapping(address => uint256) idx;
    mapping(address => uint256) allocationTargets;
}

struct Deposits {
    address[] tokens;
    mapping(address => uint256) idx;
    mapping(address => uint256) amounts;
}

using OmniLib for WhitelistedTokens global;
using OmniLib for FeeConfig global;
using OmniLib for Deposits global;

library OmniLib {

    function exists(WhitelistedTokens storage _whitelisted, address _token) internal view returns (bool) {
        return _whitelisted.idx[_token] != 0;
    }

    function add(WhitelistedTokens storage _whitelisted, address _token) internal {
        if (exists(_whitelisted, _token)) {
           revert("Token already whitelisted");
        }

        _whitelisted.array.push(_token);
        _whitelisted.idx[_token] = _whitelisted.array.length;
    }

    function remove(WhitelistedTokens storage _whitelisted, address _token) internal {
        uint256 tokenIdx = _whitelisted.idx[_token];

        if (tokenIdx == 0) {
            revert("Token not found");
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
        delete _whitelisted.allocationTargets[_token];
    }

    function exists(Deposits storage _deposits, address _token) internal view returns (bool) {
        return _deposits.idx[_token] != 0;
    }

    function add(Deposits storage _deposits, address _token, uint256 _amount) internal {
        if (exists(_deposits, _token)) {
           _deposits.amounts[_token] += _amount;
        }

        _deposits.tokens.push(_token);
        _deposits.idx[_token] = _deposits.tokens.length;
        _deposits.amounts[_token] = _amount;
    }

    function remove(Deposits storage _deposits, address _token, uint256 _amount) internal returns (uint256) {
        uint256 tokenIdx = _deposits.idx[_token];

        if (tokenIdx == 0) {
            return _amount;
        }

        if (_deposits.amounts[_token] >= _amount) {
            unchecked {
                _deposits.amounts[_token] -= _amount;
            }
            return 0;
        }

        uint256 unspent;
        unchecked {
            unspent = _amount - _deposits.amounts[_token];

            uint256 arrayIdx = tokenIdx - 1;
            uint256 lastIdx = _deposits.tokens.length - 1;

            if (arrayIdx != lastIdx) {
                address lastElement = _deposits.tokens[lastIdx];
                _deposits.tokens[arrayIdx] = lastElement;
                _deposits.idx[lastElement] = tokenIdx;
            }
        }

        _deposits.tokens.pop();
        delete _deposits.idx[_token];
        delete _deposits.amounts[_token];

        return unspent;
    }

    uint256 constant FEE_CAP_MASK = 0x000000000000FFFFFFFFFFFF0000000000000000000000000000000000000000;
    function feeCap(FeeConfig _config) internal pure returns (uint256 cap) {
        assembly {
            cap := shr(and(_config, FEE_CAP_MASK), 160)
        }
    }
    function setFeeCap(FeeConfig _config, uint256 _newFeeCap) internal pure returns (FeeConfig config) {
        assembly {
            config := add(
                and(_config, not(FEE_CAP_MASK)),
                shl(_newFeeCap, 160)
            )
        }
    }

    uint256 constant PROTOCOL_FEE_MASK = 0xFFFFFFFFFFFF0000000000000000000000000000000000000000000000000000;
    function protocolFee(FeeConfig _config) internal pure returns (uint256 fee) {
        assembly {
            fee := shr(and(_config, PROTOCOL_FEE_MASK), 208)
        }
    }
    function setProtocolFee(FeeConfig _config, uint256 _newProtocolFee) internal pure returns (FeeConfig config) {
        assembly {
            config := add(
                and(_config, not(PROTOCOL_FEE_MASK)),
                shl(_newProtocolFee, 208)
            )
        }
    }

    uint256 constant TREASURY_MASK = 0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    function treasury(FeeConfig _config) internal pure returns (address trsr) {
        assembly {
            trsr := and(_config, TREASURY_MASK)
        }
    }
    function setTreasury(FeeConfig _config, address _newTreasury) internal pure returns (FeeConfig config) {
        assembly {
            config := add(
                and(_config, not(TREASURY_MASK)),
                _newTreasury
            )
        }
    }
}

// solhint-disable-next-line
function pack(uint256 _protocolFee, uint256 _cap, address _treasury) pure returns (FeeConfig config) {
    assembly {
        config := add(
            add(
                shl(_protocolFee, 208),
                shl(_cap, 160)
            ),
            _treasury
        )
    }
}

uint256 constant PRECISION = 1e18;
uint256 constant FEE_BASIS_POINTS = 10_000;
uint256 constant WHITELISTED = 
    0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
