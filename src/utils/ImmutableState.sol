// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMultiHookAdapterBase} from "../interfaces/IMultiHookAdapterBase.sol";
import {IImmutableState} from "../interfaces/IImmutableState.sol";

/// @title Immutable State
/// @notice An extension of the original UniswapV4 ImmutableState contract purposed for the MultilHookAdapter
/// @notice Original implementation: https://github.com/Uniswap/v4-periphery/blob/main/src/base/ImmutableState.sol

contract ImmutableState is IImmutableState {

    IMultiHookAdapterBase public immutable multiHookAdapter;

    /// @notice thrown when caller is not a MultiHookAdapter contract
    modifier onlyMultiHookAdapter() {
        require(msg.sender == address(multiHookAdapter), "Caller is not the MultiHookAdapter");
        _;
    }

    constructor(IMultiHookAdapterBase _multiHookAdapter) {
        multiHookAdapter = _multiHookAdapter;
    }

}
