// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { WhitelistedTokens, FeeConfig, pack} from  "./OmniLib.sol";
import { IOracle } from "../../interfaces/IOracle.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Configuration is Ownable {

    event OracleChanged(
        address oldOracle,
        address newOracle
    );
    event FeeCapChanged(
        uint256 oldFeeCap,
        uint256 newFeeCap
    );
    event ProtocolFeeChanged(
        uint256 oldProtocolFee,
        uint256 newProtocolFee
    );
    event AddedToken(address token);
    event RemovedToken(address token);
    event SetTargetAllocation(
        address token,
        uint256 targetAllocation
    );
     event SetTreasury(
        address oldTreasury,
        address newTreasury
    );

    WhitelistedTokens internal _whitelist;
    IOracle public oracle;
    FeeConfig internal _feeConfig;

    constructor(
        address _oracle,
        address _treasury,
        uint256 _protocolFee,
        uint256 _feeCap
    ) {
        oracle = IOracle(_oracle);
        _feeConfig = pack(_protocolFee, _feeCap, _treasury);
    }

    function setTargetAllocation(address _token, uint256 _targetAllocation) external onlyOwner {
        _whitelist.allocationTargets[_token] = _targetAllocation;
        emit SetTargetAllocation(_token, _targetAllocation);
    }

    function addToken(address _token, uint256 _targetAllocation) external onlyOwner {
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

    function setOracle(address _newOracle) external onlyOwner {
        address oldOracle = address(oracle);
        oracle = IOracle(_newOracle);

        emit OracleChanged(
            oldOracle,
            _newOracle
        );
    }

    function setFeeConfig(uint256 _newFeeCap, uint256 _newProtocolFee, address _newTreasury) external onlyOwner {
        uint256 oldFeeCap = _feeConfig.feeCap();
        uint256 oldProtocolFee = _feeConfig.protocolFee();
        address oldTreasury = _feeConfig.treasury();

        _feeConfig = pack(_newFeeCap, _newProtocolFee, _newTreasury);

        emit SetTreasury(oldTreasury, _newTreasury);
        emit FeeCapChanged(oldFeeCap, _newFeeCap);
        emit ProtocolFeeChanged(oldProtocolFee, _newProtocolFee);
    }

    function setFeeCap(uint256 _newFeeCap) external onlyOwner {
        uint256 oldFeeCap = _feeConfig.feeCap();

        _feeConfig = _feeConfig.setFeeCap(_newFeeCap);

        emit FeeCapChanged(
            oldFeeCap,
            _newFeeCap
        );
    }

    function setProtocolFee(uint256 _newProtocolFee) external onlyOwner {
        uint256 oldProtocolFee = _feeConfig.protocolFee();

        _feeConfig = _feeConfig.setProtocolFee(_newProtocolFee);

        emit ProtocolFeeChanged(
            oldProtocolFee,
            _newProtocolFee
        );
    }

    function setTreasury(address _newTreasury) external onlyOwner {
        address oldTreasury = _newTreasury;

        _feeConfig = _feeConfig.setTreasury(_newTreasury);

        emit SetTreasury(oldTreasury, _newTreasury);
    }
}