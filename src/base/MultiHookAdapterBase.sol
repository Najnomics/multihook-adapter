// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// Import necessary Uniswap v4 core types and interfaces
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, toBalanceDelta, BalanceDeltaLibrary, add} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

/// @title MultiHooksAdapterBase
/// @notice Adapter contract that allows multiple hook contracts to be attached to a Uniswap V4 pool.
/// @dev It implements the IHooks interface and delegates each callback to a set of sub-hooks registered per pool, in order.
/// @dev Would be inherited by child contracts to place restrictions on hooks mutability

abstract contract MultiHooksAdapterBase is BaseHook {

    using Hooks for IHooks;
    
     /// @dev Mapping from PoolId to an ordered list of hook contracts that are invoked for that pool.
    mapping(PoolId => IHooks[]) internal _hooksByPool;

    /// @dev Temporary storage for beforeSwap returns of sub-hooks, keyed by PoolId.
    mapping(PoolId => BeforeSwapDelta[]) internal beforeSwapHookReturns;

    /// @dev Reentrancy lock state (1 = unlocked, 2 = locked).
    uint256 private locked = 1;
    modifier lock() {
        require(locked == 1, "MultiHooksAdapter: reentrancy");
        locked = 2;
        _;
        locked = 1;
    }
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

}