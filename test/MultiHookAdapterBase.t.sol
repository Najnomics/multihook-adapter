// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiHooksAdapterBase} from "../src/base/MultiHookAdapterBase.sol";
import {TestMultiHookAdapter} from "./mocs/TestMultiHookAdapter.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {HookWithEvents} from "./mocs/HookWithEvents.sol";
import {Vm} from "forge-std/Vm.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import "forge-std/console.sol";

contract MultiHookAdapterBaseTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    TestMultiHookAdapter public adapter;

    // Named hooks for different hook functions
    HookWithEvents public beforeInitializeHook;
    HookWithEvents public afterInitializeHook;
    HookWithEvents public beforeSwapHook;
    HookWithEvents public afterSwapHook;
    HookWithEvents public beforeDonateHook;
    HookWithEvents public afterDonateHook;
    HookWithEvents public beforeAddLiquidityHook;
    HookWithEvents public afterAddLiquidityHook;
    HookWithEvents public beforeRemoveLiquidityHook;
    HookWithEvents public afterRemoveLiquidityHook;

    address public nonHookContract;
    address public zeroAddress = address(0);

    PoolKey public poolKey;
    PoolId public poolId;

    // Note: SQRT_PRICE_1_1 is already defined in Deployers

    event HooksRegistered(PoolId indexed poolId, address[] hooks);

    function setUp() public {
        // Deploy a real PoolManager for testing
        deployFreshManagerAndRouters();

        // Define flags for all hooks
        uint160 adapterFlags = uint160(
            Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG
                | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_DONATE_FLAG
                | Hooks.BEFORE_DONATE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_INITIALIZE_FLAG
        );

        // Deploy adapter to a valid hook address using deployCodeTo
        address adapterAddress = address(uint160(adapterFlags));
        deployCodeTo("TestMultiHookAdapter.sol", abi.encode(manager), adapterAddress);
        adapter = TestMultiHookAdapter(adapterAddress);

        // Deploy each hook with its specific flag
        deployHookWithFlag("beforeInitializeHook", Hooks.BEFORE_INITIALIZE_FLAG);
        deployHookWithFlag("afterInitializeHook", Hooks.AFTER_INITIALIZE_FLAG);
        deployHookWithFlag("beforeSwapHook", Hooks.BEFORE_SWAP_FLAG);
        deployHookWithFlag("afterSwapHook", Hooks.AFTER_SWAP_FLAG);
        deployHookWithFlag("beforeDonateHook", Hooks.BEFORE_DONATE_FLAG);
        deployHookWithFlag("afterDonateHook", Hooks.AFTER_DONATE_FLAG);
        deployHookWithFlag("beforeAddLiquidityHook", Hooks.BEFORE_ADD_LIQUIDITY_FLAG);
        deployHookWithFlag("afterAddLiquidityHook", Hooks.AFTER_ADD_LIQUIDITY_FLAG);
        deployHookWithFlag("beforeRemoveLiquidityHook", Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG);
        deployHookWithFlag("afterRemoveLiquidityHook", Hooks.AFTER_REMOVE_LIQUIDITY_FLAG);

        // Create a non-hook contract for testing
        nonHookContract = address(new NonHookContract());

        // Setup pool information
        currency0 = Currency.wrap(address(0x1));
        currency1 = Currency.wrap(address(0x2));
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        poolId = poolKey.toId();
    }

    // Helper function to deploy a hook with a specific flag
    function deployHookWithFlag(string memory hookName, uint160 flag) private {
        address hookAddress = address(uint160(flag));
        deployCodeTo("HookWithEvents.sol", "", hookAddress);

        if (keccak256(bytes(hookName)) == keccak256(bytes("beforeInitializeHook"))) {
            beforeInitializeHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("afterInitializeHook"))) {
            afterInitializeHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("beforeSwapHook"))) {
            beforeSwapHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("afterSwapHook"))) {
            afterSwapHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("beforeDonateHook"))) {
            beforeDonateHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("afterDonateHook"))) {
            afterDonateHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("beforeAddLiquidityHook"))) {
            beforeAddLiquidityHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("afterAddLiquidityHook"))) {
            afterAddLiquidityHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("beforeRemoveLiquidityHook"))) {
            beforeRemoveLiquidityHook = HookWithEvents(hookAddress);
        } else if (keccak256(bytes(hookName)) == keccak256(bytes("afterRemoveLiquidityHook"))) {
            afterRemoveLiquidityHook = HookWithEvents(hookAddress);
        }
    }

    function test_RegisterHooks_Success() public {
        // Setup hook addresses
        address[] memory hookAddresses = new address[](3);
        hookAddresses[0] = address(beforeInitializeHook);
        hookAddresses[1] = address(afterInitializeHook);
        hookAddresses[2] = address(beforeDonateHook);

        // Expect the HooksRegistered event to be emitted
        vm.expectEmit(true, true, true, true);
        emit HooksRegistered(poolId, hookAddresses);

        // Register hooks
        adapter.registerHooks(poolKey, hookAddresses);

        // Verify hooks were registered in the correct order
        IHooks[] memory registeredHooks = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks.length, 3, "Should register 3 hooks");
        assertEq(address(registeredHooks[0]), address(beforeInitializeHook), "First hook should match");
        assertEq(address(registeredHooks[1]), address(afterInitializeHook), "Second hook should match");
        assertEq(address(registeredHooks[2]), address(beforeDonateHook), "Third hook should match");
    }

    function test_RegisterHooks_EmptyArray() public {
        // Setup empty hook addresses array
        address[] memory hookAddresses = new address[](0);

        // Register hooks with empty array
        adapter.registerHooks(poolKey, hookAddresses);

        // Verify no hooks were registered
        IHooks[] memory registeredHooks = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks.length, 0, "Should register 0 hooks");
    }

    function test_RegisterHooks_Overwrite() public {
        // First registration with two hooks
        address[] memory hookAddresses1 = new address[](2);
        hookAddresses1[0] = address(beforeInitializeHook);
        hookAddresses1[1] = address(afterInitializeHook);

        adapter.registerHooks(poolKey, hookAddresses1);

        // Verify first registration
        IHooks[] memory registeredHooks1 = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks1.length, 2, "Should register 2 hooks");

        // Second registration with different hooks
        address[] memory hookAddresses2 = new address[](1);
        hookAddresses2[0] = address(beforeDonateHook);

        adapter.registerHooks(poolKey, hookAddresses2);

        // Verify second registration overwrote the first
        IHooks[] memory registeredHooks2 = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks2.length, 1, "Should now have 1 hook");
        assertEq(address(registeredHooks2[0]), address(beforeDonateHook), "Should be the beforeDonateHook");
    }

    function test_RegisterHooks_RevertOnZeroAddress() public {
        // Setup hook addresses with zero address
        address[] memory hookAddresses = new address[](3);
        hookAddresses[0] = address(beforeInitializeHook);
        hookAddresses[1] = address(0);
        hookAddresses[2] = address(afterInitializeHook);

        // Expect revert with custom error
        vm.expectRevert(abi.encodeWithSignature("HookAddressZero()"));
        adapter.registerHooks(poolKey, hookAddresses);
    }

    function test_RegisterHooks_DifferentPools() public {
        // Create a second pool key
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(address(0x3)),
            currency1: Currency.wrap(address(0x4)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        PoolId poolId2 = poolKey2.toId();

        // Register hooks for first pool
        address[] memory hookAddresses1 = new address[](1);
        hookAddresses1[0] = address(beforeInitializeHook);
        adapter.registerHooks(poolKey, hookAddresses1);

        // Register hooks for second pool
        address[] memory hookAddresses2 = new address[](2);
        hookAddresses2[0] = address(afterInitializeHook);
        hookAddresses2[1] = address(beforeDonateHook);
        adapter.registerHooks(poolKey2, hookAddresses2);

        // Verify hooks for first pool
        IHooks[] memory registeredHooks1 = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks1.length, 1, "First pool should have 1 hook");
        assertEq(
            address(registeredHooks1[0]), address(beforeInitializeHook), "First pool should have beforeInitializeHook"
        );

        // Verify hooks for second pool
        IHooks[] memory registeredHooks2 = adapter.getHooksByPool(poolId2);
        assertEq(registeredHooks2.length, 2, "Second pool should have 2 hooks");
        assertEq(
            address(registeredHooks2[0]),
            address(afterInitializeHook),
            "Second pool first hook should be afterInitializeHook"
        );
        assertEq(
            address(registeredHooks2[1]),
            address(beforeDonateHook),
            "Second pool second hook should be beforeDonateHook"
        );
    }

    function test_BeforeInitialize_SingleHook() public {
        // Setup
        address sender = address(0x123);
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        uint160 sqrtPriceX96 = SQRT_PRICE_1_1;

        // Register a single hook with BEFORE_INITIALIZE_FLAG
        address[] memory hooks = new address[](1);
        hooks[0] = address(beforeInitializeHook);
        adapter.registerHooks(testPoolKey, hooks);

        // Mock the hook's response
        vm.mockCall(
            address(beforeInitializeHook),
            abi.encodeWithSelector(IHooks.beforeInitialize.selector, sender, testPoolKey, sqrtPriceX96),
            abi.encode(IHooks.beforeInitialize.selector)
        );

        // Get the pool manager address from the adapter (which comes from BaseHook)
        address poolManagerAddress = address(adapter.poolManager());

        // Impersonate the pool manager before calling beforeInitialize
        vm.prank(poolManagerAddress);

        // Call beforeInitialize as the pool manager
        bytes4 result = adapter.beforeInitialize(sender, testPoolKey, sqrtPriceX96);

        // Verify the result
        assertEq(result, IHooks.beforeInitialize.selector, "Should return beforeInitialize selector");
    }

    function test_BeforeInitialize_MultipleHooks() public {
        // Setup
        address sender = address(0x123);
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        uint160 sqrtPriceX96 = SQRT_PRICE_1_1;

        // Create a custom hook that also has BEFORE_INITIALIZE_FLAG
        HookWithEvents secondBeforeInitializeHook;
        HookWithEvents thirdBeforeInitializeHook;

        // Deploying at different addresses but with same flags
        address secondHookAddress = address(uint160(0x2000 | Hooks.BEFORE_INITIALIZE_FLAG));
        deployCodeTo("HookWithEvents.sol", "", secondHookAddress);
        secondBeforeInitializeHook = HookWithEvents(secondHookAddress);

        address thirdHookAddress = address(uint160(0x3000 | Hooks.BEFORE_INITIALIZE_FLAG));
        deployCodeTo("HookWithEvents.sol", "", thirdHookAddress);
        thirdBeforeInitializeHook = HookWithEvents(thirdHookAddress);

        // Register multiple hooks that all implement beforeInitialize
        address[] memory hooks = new address[](3);
        hooks[0] = address(beforeInitializeHook);
        hooks[1] = address(secondBeforeInitializeHook);
        hooks[2] = address(thirdBeforeInitializeHook);

        adapter.registerHooks(testPoolKey, hooks);

        // Mock calls for each hook - they all need to return the correct selector
        vm.mockCall(
            hooks[0],
            abi.encodeWithSelector(IHooks.beforeInitialize.selector, sender, testPoolKey, sqrtPriceX96),
            abi.encode(IHooks.beforeInitialize.selector)
        );

        vm.mockCall(
            hooks[1],
            abi.encodeWithSelector(IHooks.beforeInitialize.selector, sender, testPoolKey, sqrtPriceX96),
            abi.encode(IHooks.beforeInitialize.selector)
        );

        vm.mockCall(
            hooks[2],
            abi.encodeWithSelector(IHooks.beforeInitialize.selector, sender, testPoolKey, sqrtPriceX96),
            abi.encode(IHooks.beforeInitialize.selector)
        );

        // Impersonate the pool manager
        address poolManagerAddress = address(adapter.poolManager());
        vm.prank(poolManagerAddress);

        // Call beforeInitialize as the pool manager
        bytes4 result = adapter.beforeInitialize(sender, testPoolKey, sqrtPriceX96);

        // Verify the result
        assertEq(result, IHooks.beforeInitialize.selector, "Should return beforeInitialize selector");
    }

    function test_BeforeInitialize_MixedHooks() public {
        // Setup
        address sender = address(0x123);
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        uint160 sqrtPriceX96 = SQRT_PRICE_1_1;

        // Register a mix of hooks - only beforeInitializeHook has BEFORE_INITIALIZE_FLAG
        address[] memory hooks = new address[](3);
        hooks[0] = address(beforeInitializeHook);
        hooks[1] = address(afterInitializeHook);
        hooks[2] = address(beforeDonateHook);

        adapter.registerHooks(testPoolKey, hooks);

        // Mock response for beforeInitializeHook
        vm.mockCall(
            address(beforeInitializeHook),
            abi.encodeWithSelector(IHooks.beforeInitialize.selector, sender, testPoolKey, sqrtPriceX96),
            abi.encode(IHooks.beforeInitialize.selector)
        );

        // Impersonate the pool manager
        address poolManagerAddress = address(adapter.poolManager());
        vm.prank(poolManagerAddress);

        // Call beforeInitialize as the pool manager
        bytes4 result = adapter.beforeInitialize(sender, testPoolKey, sqrtPriceX96);

        // Verify the result is correct
        assertEq(result, IHooks.beforeInitialize.selector, "Should return beforeInitialize selector");
    }

    function test_BeforeInitialize_NoImplementingHooks() public {
        // Setup
        address sender = address(0x123);
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        uint160 sqrtPriceX96 = SQRT_PRICE_1_1;

        // Register hooks but none implement BEFORE_INITIALIZE_FLAG
        address[] memory hooks = new address[](2);
        hooks[0] = address(afterInitializeHook);
        hooks[1] = address(beforeDonateHook);

        adapter.registerHooks(testPoolKey, hooks);

        // Impersonate the pool manager
        address poolManagerAddress = address(adapter.poolManager());
        vm.prank(poolManagerAddress);

        // Call beforeInitialize as the pool manager
        bytes4 result = adapter.beforeInitialize(sender, testPoolKey, sqrtPriceX96);

        // Verify the result - should still return selector even if no hooks processed
        assertEq(
            result,
            IHooks.beforeInitialize.selector,
            "Should return beforeInitialize selector even with no implementing hooks"
        );
    }

    function test_BeforeInitialize_HookFailure() public {
        // Setup
        address sender = address(0x123);
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        uint160 sqrtPriceX96 = SQRT_PRICE_1_1;

        // Register a hook with BEFORE_INITIALIZE_FLAG
        address[] memory hooks = new address[](1);
        hooks[0] = address(beforeInitializeHook);

        adapter.registerHooks(testPoolKey, hooks);

        // Mock the hook to revert when called
        vm.mockCallRevert(
            address(beforeInitializeHook),
            abi.encodeWithSelector(IHooks.beforeInitialize.selector, sender, testPoolKey, sqrtPriceX96),
            "Hook execution failed"
        );

        // Impersonate the pool manager
        address poolManagerAddress = address(adapter.poolManager());
        vm.prank(poolManagerAddress);

        // Call should revert because hook reverts
        vm.expectRevert("Sub-hook beforeInitialize failed");
        adapter.beforeInitialize(sender, testPoolKey, sqrtPriceX96);
    }

    function test_BeforeInitialize_InvalidHookReturn() public {
        // Setup
        address sender = address(0x123);
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        uint160 sqrtPriceX96 = SQRT_PRICE_1_1;

        // Register a hook with BEFORE_INITIALIZE_FLAG
        address[] memory hooks = new address[](1);
        hooks[0] = address(beforeInitializeHook);

        adapter.registerHooks(testPoolKey, hooks);

        // Mock the hook to return an invalid selector
        bytes4 invalidSelector = bytes4(keccak256("invalidSelector()"));
        vm.mockCall(
            address(beforeInitializeHook),
            abi.encodeWithSelector(IHooks.beforeInitialize.selector, sender, testPoolKey, sqrtPriceX96),
            abi.encode(invalidSelector)
        );

        // Impersonate the pool manager
        address poolManagerAddress = address(adapter.poolManager());
        vm.prank(poolManagerAddress);

        // Call should revert because hook returns invalid selector
        vm.expectRevert("Invalid beforeInitialize return");
        adapter.beforeInitialize(sender, testPoolKey, sqrtPriceX96);
    }

    function test_BeforeInitialize_NoRegisteredHooks() public {
        // Setup
        address sender = address(0x123);
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        uint160 sqrtPriceX96 = SQRT_PRICE_1_1;

        // Don't register any hooks for this pool

        // Impersonate the pool manager
        address poolManagerAddress = address(adapter.poolManager());
        vm.prank(poolManagerAddress);

        // Call beforeInitialize as the pool manager
        bytes4 result = adapter.beforeInitialize(sender, testPoolKey, sqrtPriceX96);

        // Should still return the correct selector even with no hooks registered
        assertEq(
            result, IHooks.beforeInitialize.selector, "Should return beforeInitialize selector with no hooks registered"
        );
    }
}

// Non-hook contract for testing
contract NonHookContract {
    // This contract doesn't implement the IBaseHookExtension interface
    function foo() public pure returns (uint256) {
        return 42;
    }
}
