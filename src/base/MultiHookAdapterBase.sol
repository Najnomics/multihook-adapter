// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import necessary Uniswap v4 core types and interfaces
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, toBalanceDelta, BalanceDeltaLibrary, add} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {IBaseHookExtension} from "../interfaces/IBaseHookExtension.sol";
import {IMultiHookAdapterBase} from "../interfaces/IMultiHookAdapterBase.sol";

/// @title MultiHooksAdapterBase
/// @notice Adapter contract that allows multiple hook contracts to be attached to a Uniswap V4 pool.
/// @dev It implements the IHooks interface and delegates each callback to a set of sub-hooks registered per pool, in order.
/// @dev Would be inherited by child contracts to place restrictions on hooks mutability

abstract contract MultiHooksAdapterBase is BaseHook, IMultiHookAdapterBase {
    using Hooks for IHooks;
    
     /// @dev Mapping from PoolId to an ordered list of hook contracts that are invoked for that pool.
    mapping(PoolId => IHooks[]) internal _hooksByPool;

    /// @dev Temporary storage for beforeSwap returns of sub-hooks, keyed by PoolId.
    mapping(PoolId => BeforeSwapDelta[]) internal beforeSwapHookReturns;

    /// @dev Reentrancy lock state (1 = unlocked, 2 = locked).
    uint256 private locked = 1;
    
    modifier lock() {
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    /// @notice Registers an array of sub-hooks to be used for a given pool.
    /// @param key The PoolKey identifying the pool for which to register hooks.
    /// @param hookAddresses The ordered list of hook contract addresses to attach.
    /// Each hook in the list will be invoked in sequence for each relevant callback.
    function registerHooks(PoolKey calldata key, address[] calldata hookAddresses) external virtual override {
        _registerHooks(key, hookAddresses);
    }
    
    /// @dev Internal implementation of registerHooks that can be called by inheriting contracts
    function _registerHooks(PoolKey calldata key, address[] calldata hookAddresses) internal {
        PoolId poolId = key.toId();
        // Clear any existing hooks for the pool
        delete _hooksByPool[poolId];
        // Set new hooks in the specified order
        uint256 count = hookAddresses.length;
        IHooks[] storage hookList = _hooksByPool[poolId];

        for (uint256 i = 0; i < count; i++) {
            IHooks hook = IHooks(hookAddresses[i]);
            if (hookAddresses[i] == address(0)) revert HookAddressZero();
            if (!hook.isValidHookAddress(key.fee)) revert InvalidHookAddress();
            hookList.push(hook);
        }
        
        // Emit event when hooks are registered
        emit HooksRegistered(poolId, hookAddresses);
    }
}