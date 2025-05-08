// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

/// @title IMultiHookAdapterBase
/// @notice An interface for the MultiHookAdapterBase contract
interface IMultiHookAdapterBase {
    /// @notice Thrown when a zero address is provided as a hook
    error HookAddressZero();

    /// @notice Thrown when a hook address is invalid for the given fee tier
    error InvalidHookAddress();

    /// @notice Thrown when trying to perform a reentrant call
    error Reentrancy();

    /// @notice Emitted when hooks are registered for a pool
    /// @param poolId The ID of the pool for which hooks were registered
    /// @param hookAddresses The addresses of the hooks registered
    event HooksRegistered(PoolId indexed poolId, address[] hookAddresses);

    /// @notice Registers an array of sub-hooks to be used for a given pool.
    /// @param key The PoolKey identifying the pool for which to register hooks.
    /// @param hookAddresses The ordered list of hook contract addresses to attach.
    /// Each hook in the list will be invoked in sequence for each relevant callback.
    function registerHooks(PoolKey calldata key, address[] calldata hookAddresses) external;
}
