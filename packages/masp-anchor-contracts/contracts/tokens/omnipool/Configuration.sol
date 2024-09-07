// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { WhitelistedTokens } from  "./OmniLib.sol";
import { IOracle } from "../../interfaces/IOracle.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Configuration is Ownable {

    event OracleChanged(
        address oldOracle,
        address newOracle
    );
    event FeeCapChanged(
        uint256 oldOracle,
        uint256 newOracle
    );
    event AddedToken(address token);
    event RemovedToken(address token);
    event SetTargetAllocation(
        address token,
        uint256 targetAllocation
    );

    WhitelistedTokens internal _whitelist;
    IOracle public oracle;
    uint256 public feeCap;

    constructor(
        address _oracle,
        uint256 _feeCap
    ) {
        oracle = IOracle(_oracle);
        feeCap = _feeCap;
    }

    function setTargetAllocation(address _token, uint256 _targetAllocation) external onlyOwner {
        _whitelist.allocationTargets[_token] = _targetAllocation;
        emit SetTargetAllocation(_token, _targetAllocation);
    }

    function addToken(address _token, uint256 _targetAllocation) external onlyOwner {
        // add token to whitelist
        _whitelist.add(_token);
        emit AddedToken(_token);
        // set allocation target
        _whitelist.allocationTargets[_token] = _targetAllocation;
        emit SetTargetAllocation(_token, _targetAllocation);
    }

    function removeToken(address _token) external onlyOwner {
        _whitelist.remove(_token);
        emit RemovedToken(_token);
    }

    function setOracle(
        address _newOracle
    ) external onlyOwner {

        address oldOracle = address(oracle);
        oracle = IOracle(_newOracle);

        emit OracleChanged(
            oldOracle,
            _newOracle
        );
    }

    function setFeeCap(
        uint256 _newFeeCap
    ) external onlyOwner {

        uint256 oldFeeCap = feeCap;
        feeCap = _newFeeCap;

        emit FeeCapChanged(
            oldFeeCap,
            _newFeeCap
        );
    }
}