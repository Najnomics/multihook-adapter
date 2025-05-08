// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import necessary Uniswap v4 core types and interfaces
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, toBalanceDelta, BalanceDeltaLibrary, add} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {
    BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary
} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
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

    /// @notice Returns the hook permissions for this adapter
    /// @return permissions The hook permissions
    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory permissions) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: true,
            afterRemoveLiquidityReturnDelta: true
        });
    }

    function _beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
        internal
        override
        lock
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        IHooks[] storage subHooks = _hooksByPool[poolId];
        // Invoke beforeInitialize on each sub-hook in order:contentReference[oaicite:2]{index=2}.
        uint256 length = subHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            // Only call if the sub-hook is permissioned for beforeInitialize
            if (uint160(address(subHooks[i])) & Hooks.BEFORE_INITIALIZE_FLAG != 0) {
                // Call sub-hook; since beforeInitialize returns only a selector, we ignore returned data beyond selector check.
                (bool success, bytes memory result) = address(subHooks[i]).call(
                    abi.encodeWithSelector(IHooks.beforeInitialize.selector, sender, key, sqrtPriceX96)
                );
                require(success, "Sub-hook beforeInitialize failed");
                // Verify the returned selector for correctness
                require(
                    result.length >= 4 && bytes4(result) == IHooks.beforeInitialize.selector,
                    "Invalid beforeInitialize return"
                );
            }
        }
        // Return this function's own selector to PoolManager:contentReference[oaicite:3]{index=3}.
        return IHooks.beforeInitialize.selector;
    }

    function _afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        internal
        override
        lock
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        IHooks[] storage subHooks = _hooksByPool[poolId];
        uint256 length = subHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            if (uint160(address(subHooks[i])) & Hooks.AFTER_INITIALIZE_FLAG != 0) {
                (bool success, bytes memory result) = address(subHooks[i]).call(
                    abi.encodeWithSelector(IHooks.afterInitialize.selector, sender, key, sqrtPriceX96, tick)
                );
                require(success, "Sub-hook afterInitialize failed");
                require(
                    result.length >= 4 && bytes4(result) == IHooks.afterInitialize.selector,
                    "Invalid afterInitialize return"
                );
            }
        }
        return IHooks.afterInitialize.selector;
    }

    function _beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal override lock returns (bytes4) {
        return _beforeModifyPosition(sender, key, params, hookData);
    }

    function _beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal override lock returns (bytes4) {
        return _beforeModifyPosition(sender, key, params, hookData);
    }

    function _beforeModifyPosition(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata data
    ) internal onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();
        IHooks[] storage subHooks = _hooksByPool[poolId];
        bool addingLiquidity = params.liquidityDelta > 0;

        uint256 length = subHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            uint160 hookPerms = uint160(address(subHooks[i]));
            if (addingLiquidity) {
                // If adding liquidity, call sub-hook if it has beforeAddLiquidity permission
                if (hookPerms & Hooks.BEFORE_ADD_LIQUIDITY_FLAG != 0) {
                    (bool success, bytes memory result) = address(subHooks[i]).call(
                        abi.encodeWithSelector(IHooks.beforeAddLiquidity.selector, sender, key, params, data)
                    );
                    require(success, "Sub-hook beforeAddLiquidity failed");
                    require(
                        result.length >= 4 && bytes4(result) == IHooks.beforeAddLiquidity.selector,
                        "Invalid beforeAddLiquidity return"
                    );
                }
            } else {
                // If removing liquidity, call sub-hook if it has beforeRemoveLiquidity permission
                if (hookPerms & Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG != 0) {
                    (bool success, bytes memory result) = address(subHooks[i]).call(
                        abi.encodeWithSelector(IHooks.beforeRemoveLiquidity.selector, sender, key, params, data)
                    );
                    require(success, "Sub-hook beforeRemoveLiquidity failed");
                    require(
                        result.length >= 4 && bytes4(result) == IHooks.beforeRemoveLiquidity.selector,
                        "Invalid beforeRemoveLiquidity return"
                    );
                }
            }
        }

        // Return the appropriate selector based on the operation type
        return addingLiquidity ? IHooks.beforeAddLiquidity.selector : IHooks.beforeRemoveLiquidity.selector;
    }
}
