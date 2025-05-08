// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "../../src/utils/BaseHookExtension.sol";
import {IMultiHookAdapterBase} from "../../src/interfaces/IMultiHookAdapterBase.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract MockBaseHook is BaseHook {
    constructor(IMultiHookAdapterBase adapter) BaseHook(adapter) {}

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
    function validateHookAddress(BaseHook _this) internal pure override {
        // Skip validation for testing
    }
}
