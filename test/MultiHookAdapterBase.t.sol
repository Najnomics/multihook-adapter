// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IBaseHookExtension} from "../src/interfaces/IBaseHookExtension.sol";
import {MockSubHook} from "./mocs/MockSubHook.sol";
import {TestMultiHookAdapter} from "./mocs/TestMultiHookAdapter.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MultiHooksAdapterBase} from "../src/base/MultiHookAdapterBase.sol";
import "forge-std/console.sol";

contract MultiHookAdapterBaseTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    TestMultiHookAdapter public adapter;
    MockSubHook public mockHook1;
    MockSubHook public mockHook2;
    MockSubHook public mockHook3;

    address public nonHookContract;
    address public zeroAddress = address(0);

    PoolKey public poolKey;
    PoolId public poolId;

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

        // Deploy all three hooks with the same flags but at different addresses
        // Hook 1: Combine adapter flags with BEFORE_INITIALIZE_FLAG
        uint160 hook1Flags = Hooks.BEFORE_INITIALIZE_FLAG;
        address hook1Address = address(uint160(hook1Flags));
        deployCodeTo("MockSubHook.sol", abi.encode(adapter), hook1Address);
        mockHook1 = MockSubHook(hook1Address);

        // Hook 2: Combine adapter flags with AFTER_INITIALIZE_FLAG
        uint160 hook2Flags = Hooks.AFTER_INITIALIZE_FLAG;
        address hook2Address = address(uint160(hook2Flags));
        deployCodeTo("MockSubHook.sol", abi.encode(adapter), hook2Address);
        mockHook2 = MockSubHook(hook2Address);

        // Hook 3: Combine adapter flags with BEFORE_DONATE_FLAG
        uint160 hook3Flags = Hooks.BEFORE_DONATE_FLAG;
        address hook3Address = address(uint160(hook3Flags));
        deployCodeTo("MockSubHook.sol", abi.encode(adapter), hook3Address);
        mockHook3 = MockSubHook(hook3Address);

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

    function test_RegisterHooks_Success() public {
        // Setup hook addresses
        address[] memory hookAddresses = new address[](3);
        hookAddresses[0] = address(mockHook1);
        hookAddresses[1] = address(mockHook2);
        hookAddresses[2] = address(mockHook3);

        // Expect the HooksRegistered event to be emitted
        vm.expectEmit(true, true, true, true);
        emit HooksRegistered(poolId, hookAddresses);

        // Register hooks
        adapter.registerHooks(poolKey, hookAddresses);

        // Verify hooks were registered in the correct order
        IHooks[] memory registeredHooks = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks.length, 3, "Should register 3 hooks");
        assertEq(address(registeredHooks[0]), address(mockHook1), "First hook should match");
        assertEq(address(registeredHooks[1]), address(mockHook2), "Second hook should match");
        assertEq(address(registeredHooks[2]), address(mockHook3), "Third hook should match");
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
        hookAddresses1[0] = address(mockHook1);
        hookAddresses1[1] = address(mockHook2);

        adapter.registerHooks(poolKey, hookAddresses1);

        // Verify first registration
        IHooks[] memory registeredHooks1 = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks1.length, 2, "Should register 2 hooks");

        // Second registration with different hooks
        address[] memory hookAddresses2 = new address[](1);
        hookAddresses2[0] = address(mockHook3);

        adapter.registerHooks(poolKey, hookAddresses2);

        // Verify second registration overwrote the first
        IHooks[] memory registeredHooks2 = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks2.length, 1, "Should now have 1 hook");
        assertEq(address(registeredHooks2[0]), address(mockHook3), "Should be the third hook");
    }

    function test_RegisterHooks_RevertOnZeroAddress() public {
        // Setup hook addresses with zero address
        address[] memory hookAddresses = new address[](3);
        hookAddresses[0] = address(mockHook1);
        hookAddresses[1] = address(0);
        hookAddresses[2] = address(mockHook3);

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
        hookAddresses1[0] = address(mockHook1);
        adapter.registerHooks(poolKey, hookAddresses1);

        // Register hooks for second pool
        address[] memory hookAddresses2 = new address[](2);
        hookAddresses2[0] = address(mockHook2);
        hookAddresses2[1] = address(mockHook3);
        adapter.registerHooks(poolKey2, hookAddresses2);

        // Verify hooks for first pool
        IHooks[] memory registeredHooks1 = adapter.getHooksByPool(poolId);
        assertEq(registeredHooks1.length, 1, "First pool should have 1 hook");
        assertEq(address(registeredHooks1[0]), address(mockHook1), "First pool should have mockHook1");

        // Verify hooks for second pool
        IHooks[] memory registeredHooks2 = adapter.getHooksByPool(poolId2);
        assertEq(registeredHooks2.length, 2, "Second pool should have 2 hooks");
        assertEq(address(registeredHooks2[0]), address(mockHook2), "Second pool first hook should be mockHook2");
        assertEq(address(registeredHooks2[1]), address(mockHook3), "Second pool second hook should be mockHook3");
    }
}

// Non-hook contract for testing
contract NonHookContract {
    // This contract doesn't implement the IBaseHookExtension interface
    function foo() public pure returns (uint256) {
        return 42;
    }
}
