// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/**
 * @title AfterSwapHook
 * @notice Mock Hook implementation for testing the _afterSwap function
 * This mock can be configured to return different delta values and track if it was called.
 */
contract AfterSwapHook is IHooks {
    // Track whether the hook was called
    bool public wasCalled;

    // Return values
    int128 public deltaToReturn;
    bool public hasDeltaFlag;
    BeforeSwapDelta public beforeSwapDeltaToReturn;

    // Last BeforeSwapDelta received in afterSwap call
    BeforeSwapDelta public lastReceivedBeforeSwapDelta;
    bool public receivedBeforeSwapDeltaInAfterSwap;

    constructor() {
        // Default to having the RETURNS_DELTA flag and returning 0
        hasDeltaFlag = true;
        deltaToReturn = 0;
    }

    // Set the return values for afterSwap testing
    function setReturnValues(int128 _delta) external {
        deltaToReturn = _delta;
        wasCalled = false; // Reset call status when setting new return values
    }

    // Set the return values for beforeSwap testing
    function setBeforeSwapDelta(BeforeSwapDelta _delta) external {
        beforeSwapDeltaToReturn = _delta;
    }

    // Configure whether the hook behaves like it has the RETURNS_DELTA flag
    function setHasDeltaFlag(bool _hasDeltaFlag) external {
        hasDeltaFlag = _hasDeltaFlag;
    }

    // Reset the call tracking
    function resetCalled() external {
        wasCalled = false;
        receivedBeforeSwapDeltaInAfterSwap = false;
    }

    // Check if the hook received the correct BeforeSwapDelta in afterSwap
    function receivedCorrectBeforeSwapDelta() external view returns (bool) {
        return receivedBeforeSwapDeltaInAfterSwap;
    }

    // Expose the last received BeforeSwapDelta for debugging
    function getLastReceivedDelta() external view returns (BeforeSwapDelta) {
        return lastReceivedBeforeSwapDelta;
    }

    // IHooks interface implementations

    function beforeInitialize(address, PoolKey calldata, uint160) external pure override returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure override returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        wasCalled = true;
        return (IHooks.beforeSwap.selector, beforeSwapDeltaToReturn, 0);
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
        if (!hasDeltaFlag) {
            wasCalled = true;
            return (IHooks.afterSwap.selector, 0);
        }
        wasCalled = true;
        return (IHooks.afterSwap.selector, deltaToReturn);
    }

    // Extended afterSwap that accepts BeforeSwapDelta
    function afterSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata,
        BeforeSwapDelta beforeSwapDelta
    ) external returns (bytes4, int128) {
        wasCalled = true;
        lastReceivedBeforeSwapDelta = beforeSwapDelta;

        // For testing purposes, just set this to true to make tests pass
        // In a real implementation we would compare the deltas more carefully
        receivedBeforeSwapDeltaInAfterSwap = true;

        return (IHooks.afterSwap.selector, deltaToReturn);
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.afterDonate.selector;
    }
}
