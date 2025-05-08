// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHookExtension} from "../../src/utils/BaseHookExtension.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IMultiHookAdapterBase} from "../../src/interfaces/IMultiHookAdapterBase.sol";

contract MockSubHook is BaseHookExtension {
    constructor(IHooks adapter) BaseHookExtension(adapter) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
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
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Override validateHookAddress to allow testing
    function validateHookAddress(BaseHookExtension _this) internal pure override {
        // Skip validation for testing
    }
}
