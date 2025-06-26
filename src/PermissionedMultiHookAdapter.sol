// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {MultiHookAdapterBase} from "./base/MultiHookAdapterBase.sol";
import {IFeeCalculationStrategy} from "./interfaces/IFeeCalculationStrategy.sol";

/// @title PermissionedMultiHookAdapter
/// @notice Permissioned implementation where only pool creators can manage hooks
/// @dev Hook management is restricted to pool creators only, with approved hooks from governance
contract PermissionedMultiHookAdapter is MultiHookAdapterBase {
    
    /// @notice Error thrown when hook is not in approved registry
    error HookNotApproved(address hook);
    
    /// @notice Error thrown when caller is not authorized to manage hooks (pool creator check)
    error UnauthorizedHookManagement();
    
    /// @notice Error thrown when trying to add hook that's already registered for a pool
    error HookAlreadyRegistered(PoolId poolId, address hook);
    
    /// @notice Error thrown when trying to remove hook that's not registered for a pool  
    error HookNotRegistered(PoolId poolId, address hook);
    
    /// @notice Emitted when a hook is approved for use
    /// @param hook The hook address that was approved
    /// @param approver The address that approved the hook
    event HookApproved(address indexed hook, address indexed approver);
    
    /// @notice Emitted when a hook approval is revoked
    /// @param hook The hook address that was revoked
    /// @param revoker The address that revoked the hook
    event HookApprovalRevoked(address indexed hook, address indexed revoker);
    
    /// @notice Emitted when hook manager is updated
    /// @param oldManager The previous hook manager
    /// @param newManager The new hook manager
    event HookManagerUpdated(address indexed oldManager, address indexed newManager);

    /// @notice Emitted when hooks are added to a pool
    /// @param poolId The pool ID
    /// @param addedHooks The hooks that were added
    /// @param poolCreator The address of the pool creator who added hooks
    event HooksAdded(PoolId indexed poolId, address[] addedHooks, address indexed poolCreator);
    
    /// @notice Emitted when hooks are removed from a pool
    /// @param poolId The pool ID
    /// @param removedHooks The hooks that were removed
    /// @param poolCreator The address of the pool creator who removed hooks
    event HooksRemoved(PoolId indexed poolId, address[] removedHooks, address indexed poolCreator);
    
    /// @dev Registry of approved hooks that can be used with pools
    mapping(address => bool) public approvedHooks;
    
    /// @dev Address authorized to manage hook approvals (separate from fee governance)
    address public hookManager;
    
    /// @dev Whether hook management is enabled
    bool public immutable hookManagementEnabled;

    modifier onlyHookManager() {
        if (hookManagementEnabled && msg.sender != hookManager) revert UnauthorizedHookManagement();
        _;
    }

    modifier onlyPoolCreatorForHooks(PoolId poolId) {
        address poolCreator = _poolCreators[poolId];
        if (poolCreator != address(0) && msg.sender != poolCreator) {
            revert UnauthorizedPoolCreator(poolId, msg.sender, poolCreator);
        }
        _;
    }

    constructor(
        IPoolManager _poolManager,
        uint24 _defaultFee,
        address _governance,
        address _hookManager,
        bool _hookManagementEnabled
    ) MultiHookAdapterBase(_poolManager, _defaultFee, _governance, true) {
        hookManager = _hookManager;
        hookManagementEnabled = _hookManagementEnabled;
    }

    /// @notice Approve a hook for use in pools (only by hook manager)
    /// @param hook The hook address to approve
    function approveHook(address hook) external onlyHookManager {
        require(hook != address(0), "Invalid hook address");
        approvedHooks[hook] = true;
        emit HookApproved(hook, msg.sender);
    }
    
    /// @notice Revoke approval for a hook (only by hook manager)
    /// @param hook The hook address to revoke
    function revokeHookApproval(address hook) external onlyHookManager {
        approvedHooks[hook] = false;
        emit HookApprovalRevoked(hook, msg.sender);
    }
    
    /// @notice Set the hook manager address (only by governance)
    /// @param newHookManager The new hook manager address
    function setHookManager(address newHookManager) external onlyGovernance {
        address oldManager = hookManager;
        hookManager = newHookManager;
        emit HookManagerUpdated(oldManager, newHookManager);
    }
    
    /// @notice Register hooks for a pool (restricted to pool creators, with approval check)
    /// @param key The PoolKey identifying the pool
    /// @param hookAddresses The ordered list of hook contract addresses
    function registerHooks(PoolKey calldata key, address[] calldata hookAddresses) external override {
        PoolId poolId = key.toId();
        
        // If no pool creator is registered, register the caller as the pool creator
        if (_poolCreators[poolId] == address(0)) {
            _poolCreators[poolId] = msg.sender;
            emit PoolCreatorRegistered(poolId, msg.sender);
        }
        
        // Only allow the pool creator to register hooks
        if (msg.sender != _poolCreators[poolId]) {
            revert UnauthorizedPoolCreator(poolId, msg.sender, _poolCreators[poolId]);
        }
        
        // Verify all hooks are approved
        for (uint256 i = 0; i < hookAddresses.length; i++) {
            if (!approvedHooks[hookAddresses[i]]) {
                revert HookNotApproved(hookAddresses[i]);
            }
        }
        
        // Register hooks using parent implementation
        _registerHooks(key, hookAddresses);
    }
    
    /// @notice Add hooks to an existing pool (only by pool creator)
    /// @param poolId The pool to add hooks to
    /// @param newHooks The hooks to add
    function addHooksToPool(PoolId poolId, address[] calldata newHooks) external onlyPoolCreatorForHooks(poolId) {
        // Verify all new hooks are approved
        for (uint256 i = 0; i < newHooks.length; i++) {
            if (!approvedHooks[newHooks[i]]) {
                revert HookNotApproved(newHooks[i]);
            }
        }
        
        // Get current hooks
        IHooks[] storage currentHooks = _hooksByPool[poolId];
        
        // Check for duplicates
        for (uint256 i = 0; i < newHooks.length; i++) {
            for (uint256 j = 0; j < currentHooks.length; j++) {
                if (address(currentHooks[j]) == newHooks[i]) {
                    revert HookAlreadyRegistered(poolId, newHooks[i]);
                }
            }
        }
        
        // Add new hooks
        for (uint256 i = 0; i < newHooks.length; i++) {
            currentHooks.push(IHooks(newHooks[i]));
        }
        
        emit HooksAdded(poolId, newHooks, msg.sender);
    }
    
    /// @notice Remove hooks from a pool (only by pool creator)
    /// @param poolId The pool to remove hooks from
    /// @param hooksToRemove The hook addresses to remove
    function removeHooksFromPool(PoolId poolId, address[] calldata hooksToRemove) external onlyPoolCreatorForHooks(poolId) {
        IHooks[] storage currentHooks = _hooksByPool[poolId];
        
        // For each hook to remove
        for (uint256 i = 0; i < hooksToRemove.length; i++) {
            bool found = false;
            
            // Find and remove the hook
            for (uint256 j = 0; j < currentHooks.length; j++) {
                if (address(currentHooks[j]) == hooksToRemove[i]) {
                    // Move last element to this position and pop
                    currentHooks[j] = currentHooks[currentHooks.length - 1];
                    currentHooks.pop();
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                revert HookNotRegistered(poolId, hooksToRemove[i]);
            }
        }
        
        emit HooksRemoved(poolId, hooksToRemove, msg.sender);
    }
    
    /// @notice Replace all hooks for a pool with new ones (only by pool creator)
    /// @param poolId The pool to update
    /// @param newHooks The new set of hooks
    function replacePoolHooks(PoolId poolId, address[] calldata newHooks) external onlyPoolCreatorForHooks(poolId) {
        // Verify all new hooks are approved
        for (uint256 i = 0; i < newHooks.length; i++) {
            if (!approvedHooks[newHooks[i]]) {
                revert HookNotApproved(newHooks[i]);
            }
        }
        
        // Clear existing hooks
        delete _hooksByPool[poolId];
        
        // Add new hooks
        IHooks[] storage hookList = _hooksByPool[poolId];
        for (uint256 i = 0; i < newHooks.length; i++) {
            hookList.push(IHooks(newHooks[i]));
        }
        
        emit HooksRegistered(poolId, newHooks);
    }
    
    /// @notice Get current hooks for a pool
    /// @param poolId The pool ID
    /// @return hooks Array of hook addresses
    function getPoolHooks(PoolId poolId) external view returns (address[] memory hooks) {
        IHooks[] storage poolHooks = _hooksByPool[poolId];
        hooks = new address[](poolHooks.length);
        for (uint256 i = 0; i < poolHooks.length; i++) {
            hooks[i] = address(poolHooks[i]);
        }
    }
    
    /// @notice Check if a hook is approved
    /// @param hook The hook address to check
    /// @return approved True if the hook is approved
    function isHookApproved(address hook) external view returns (bool approved) {
        return approvedHooks[hook];
    }
    
    /// @notice Batch approve multiple hooks (only by hook manager)
    /// @param hooks Array of hook addresses to approve
    function batchApproveHooks(address[] calldata hooks) external onlyHookManager {
        for (uint256 i = 0; i < hooks.length; i++) {
            require(hooks[i] != address(0), "Invalid hook address");
            approvedHooks[hooks[i]] = true;
            emit HookApproved(hooks[i], msg.sender);
        }
    }
    
    /// @notice Batch revoke approval for multiple hooks (only by hook manager)
    /// @param hooks Array of hook addresses to revoke
    function batchRevokeHookApprovals(address[] calldata hooks) external onlyHookManager {
        for (uint256 i = 0; i < hooks.length; i++) {
            approvedHooks[hooks[i]] = false;
            emit HookApprovalRevoked(hooks[i], msg.sender);
        }
    }

    /// @notice Override fee configuration methods to restrict to pool creators
    function setPoolFeeCalculationMethod(
        PoolId poolId, 
        IFeeCalculationStrategy.FeeCalculationMethod method
    ) external override onlyPoolCreatorForHooks(poolId) {
        _poolFeeConfigs[poolId].method = method;
        emit PoolFeeConfigurationUpdated(poolId, method, _poolFeeConfigs[poolId].poolSpecificFee);
    }
    
    /// @notice Override pool specific fee setting to restrict to pool creators
    function setPoolSpecificFee(PoolId poolId, uint24 fee) external override onlyPoolCreatorForHooks(poolId) {
        if (fee > 1_000_000) revert InvalidFee(fee);
        
        _poolFeeConfigs[poolId].poolSpecificFee = fee;
        _poolFeeConfigs[poolId].poolSpecificFeeSet = (fee > 0);
        
        emit PoolFeeConfigurationUpdated(poolId, _poolFeeConfigs[poolId].method, fee);
    }
}