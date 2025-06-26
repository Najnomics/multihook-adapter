// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {PermissionedMultiHookAdapter} from "../src/PermissionedMultiHookAdapter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IFeeCalculationStrategy} from "../src/interfaces/IFeeCalculationStrategy.sol";
import {IMultiHookAdapterBase} from "../src/interfaces/IMultiHookAdapterBase.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";

/// @title PoolCreatorAccessTest
/// @notice Test that only pool creators can manage hooks
contract PoolCreatorAccessTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    
    PermissionedMultiHookAdapter adapter;
    PoolKey testKey;
    PoolId testPoolId;
    address poolCreator;
    address notPoolCreator;
    address governance;
    address hookManager;

    function setUp() public {
        deployFreshManagerAndRouters();
        
        governance = address(0x1111);
        hookManager = address(0x2222);
        poolCreator = address(0x3333);
        notPoolCreator = address(0x4444);

        // Deploy adapter with valid hook address
        uint160 adapterFlags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );
        
        address adapterAddress = address(adapterFlags);
        deployCodeTo(
            "PermissionedMultiHookAdapter.sol",
            abi.encode(manager, 1000, governance, hookManager, true),
            adapterAddress
        );
        adapter = PermissionedMultiHookAdapter(adapterAddress);

        testKey = PoolKey({
            currency0: Currency.wrap(address(0xA)),
            currency1: Currency.wrap(address(0xB)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(adapter))
        });
        testPoolId = testKey.toId();
    }

    function test_PoolCreatorCanRegisterHooks() public {
        address[] memory hooks = new address[](1);
        hooks[0] = address(0x1000);

        // Approve the hook as hookManager
        vm.prank(hookManager);
        adapter.approveHook(address(0x1000));

        // Pool creator can register hooks (first time sets them as creator)
        vm.prank(poolCreator);
        adapter.registerHooks(testKey, hooks);

        // Verify hooks were registered
        address[] memory registeredHooks = adapter.getPoolHooks(testPoolId);
        assertEq(registeredHooks.length, 1);
        assertEq(registeredHooks[0], address(0x1000));

        // Verify pool creator was recorded
        assertEq(adapter.getPoolCreator(testPoolId), poolCreator);
        assertTrue(adapter.isPoolCreator(testPoolId, poolCreator));
        assertFalse(adapter.isPoolCreator(testPoolId, notPoolCreator));
    }

    function test_NonPoolCreatorCannotRegisterHooksOnExistingPool() public {
        address[] memory hooks = new address[](1);
        hooks[0] = address(0x1000);

        // Approve the hook as hookManager
        vm.prank(hookManager);
        adapter.approveHook(address(0x1000));

        // Pool creator registers hooks first (becomes pool creator)
        vm.prank(poolCreator);
        adapter.registerHooks(testKey, hooks);

        // Non-pool creator cannot register hooks
        vm.prank(notPoolCreator);
        vm.expectRevert(abi.encodeWithSelector(
            IMultiHookAdapterBase.UnauthorizedPoolCreator.selector,
            testPoolId,
            notPoolCreator,
            poolCreator
        ));
        adapter.registerHooks(testKey, hooks);
    }

    function test_PoolCreatorCanAddHooks() public {
        address[] memory initialHooks = new address[](1);
        initialHooks[0] = address(0x1000);

        // Approve hooks
        vm.prank(hookManager);
        adapter.approveHook(address(0x1000));
        vm.prank(hookManager);
        adapter.approveHook(address(0x2000));

        // Register initial hooks
        vm.prank(poolCreator);
        adapter.registerHooks(testKey, initialHooks);

        // Pool creator can add more hooks
        address[] memory newHooks = new address[](1);
        newHooks[0] = address(0x2000);

        vm.prank(poolCreator);
        adapter.addHooksToPool(testPoolId, newHooks);

        // Verify both hooks are registered
        address[] memory allHooks = adapter.getPoolHooks(testPoolId);
        assertEq(allHooks.length, 2);
        assertEq(allHooks[0], address(0x1000));
        assertEq(allHooks[1], address(0x2000));
    }

    function test_NonPoolCreatorCannotAddHooks() public {
        address[] memory initialHooks = new address[](1);
        initialHooks[0] = address(0x1000);

        // Approve hooks
        vm.prank(hookManager);
        adapter.approveHook(address(0x1000));
        vm.prank(hookManager);
        adapter.approveHook(address(0x2000));

        // Register initial hooks as pool creator
        vm.prank(poolCreator);
        adapter.registerHooks(testKey, initialHooks);

        // Non-pool creator cannot add hooks
        address[] memory newHooks = new address[](1);
        newHooks[0] = address(0x2000);

        vm.prank(notPoolCreator);
        vm.expectRevert(abi.encodeWithSelector(
            IMultiHookAdapterBase.UnauthorizedPoolCreator.selector,
            testPoolId,
            notPoolCreator,
            poolCreator
        ));
        adapter.addHooksToPool(testPoolId, newHooks);
    }

    function test_PoolCreatorCanSetPoolFeeConfiguration() public {
        address[] memory hooks = new address[](1);
        hooks[0] = address(0x1000);

        // Approve and register hooks as pool creator
        vm.prank(hookManager);
        adapter.approveHook(address(0x1000));
        vm.prank(poolCreator);
        adapter.registerHooks(testKey, hooks);

        // Pool creator can set fee configuration
        vm.prank(poolCreator);
        adapter.setPoolSpecificFee(testPoolId, 5000); // 0.5%

        // Verify fee was set
        IFeeCalculationStrategy.FeeConfiguration memory config = adapter.getFeeConfiguration(testPoolId);
        assertEq(config.poolSpecificFee, 5000);
        assertTrue(config.poolSpecificFeeSet);
    }

    function test_NonPoolCreatorCannotSetPoolFeeConfiguration() public {
        address[] memory hooks = new address[](1);
        hooks[0] = address(0x1000);

        // Approve and register hooks as pool creator
        vm.prank(hookManager);
        adapter.approveHook(address(0x1000));
        vm.prank(poolCreator);
        adapter.registerHooks(testKey, hooks);

        // Non-pool creator cannot set fee configuration
        vm.prank(notPoolCreator);
        vm.expectRevert(abi.encodeWithSelector(
            IMultiHookAdapterBase.UnauthorizedPoolCreator.selector,
            testPoolId,
            notPoolCreator,
            poolCreator
        ));
        adapter.setPoolSpecificFee(testPoolId, 5000);
    }
}