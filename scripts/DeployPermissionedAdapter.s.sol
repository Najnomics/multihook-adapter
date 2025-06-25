// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {MultiHookAdapterFactory} from "../src/factory/MultiHookAdapterFactory.sol";
import {PermissionedMultiHookAdapter} from "../src/PermissionedMultiHookAdapter.sol";

/**
 * @title DeployPermissionedAdapter
 * @notice Deployment script for permissioned MultiHookAdapter instances
 * @dev This script deploys governance-controlled adapters with dynamic hook management
 */
contract DeployPermissionedAdapter is Script {
    // Factory address
    address public factoryAddress;
    
    // Deployment parameters
    IPoolManager public poolManager;
    uint24 public defaultFee;
    address public governance;
    address public hookManager;
    bool public enableHookManagement;
    bytes32 public salt;
    
    // Deployed adapter
    PermissionedMultiHookAdapter public adapter;

    function run() external {
        _loadConfiguration();
        _validateConfiguration();
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("================================");
        console.log("Permissioned MultiHookAdapter Deployment");
        console.log("================================");
        console.log("Deployer:", deployer);
        console.log("Factory:", factoryAddress);
        console.log("Pool Manager:", address(poolManager));
        console.log("Default Fee:", defaultFee);
        console.log("Governance:", governance);
        console.log("Hook Manager:", hookManager);
        console.log("Hook Management Enabled:", enableHookManagement);
        console.log("Salt:", vm.toString(salt));
        console.log("================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the adapter
        console.log("Deploying PermissionedMultiHookAdapter...");
        MultiHookAdapterFactory factory = MultiHookAdapterFactory(factoryAddress);
        
        // Predict the address first
        address predictedAddress = factory.predictPermissionedMultiHookAdapterAddress(
            poolManager,
            defaultFee,
            governance,
            hookManager,
            enableHookManagement,
            salt
        );
        console.log("Predicted address:", predictedAddress);

        // Deploy the adapter
        address deployedAddress = factory.deployPermissionedMultiHookAdapter(
            poolManager,
            defaultFee,
            governance,
            hookManager,
            enableHookManagement,
            salt
        );
        
        adapter = PermissionedMultiHookAdapter(deployedAddress);
        console.log("PermissionedMultiHookAdapter deployed at:", deployedAddress);
        
        // Verify prediction was correct
        require(predictedAddress == deployedAddress, "Address prediction mismatch");
        console.log("Address prediction verified [OK]");

        vm.stopBroadcast();

        // Verify deployment
        _verifyDeployment();
        
        // Save deployment info
        _saveDeploymentInfo();
        
        console.log("================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("PermissionedMultiHookAdapter:", address(adapter));
        console.log("================================");
        
        // Print next steps
        _printNextSteps();
    }

    function _loadConfiguration() internal {
        // Load factory address from environment or file
        try vm.envAddress("MULTI_HOOK_ADAPTER_FACTORY") returns (address factory) {
            factoryAddress = factory;
        } catch {
            // Try to load from deployment file
            try vm.readFile(string.concat("deployments-", vm.toString(block.chainid), ".env")) returns (string memory content) {
                factoryAddress = vm.parseAddress(_extractValue(content, "MULTI_HOOK_ADAPTER_FACTORY"));
            } catch {
                revert("Factory address not found. Deploy factory first or set MULTI_HOOK_ADAPTER_FACTORY");
            }
        }
        
        // Load pool manager address
        string memory poolManagerKey = string.concat(
            block.chainid == 11155111 ? "SEPOLIA" : "MAINNET",
            "_POOL_MANAGER"
        );
        poolManager = IPoolManager(vm.envAddress(poolManagerKey));
        
        // Load default fee
        defaultFee = uint24(vm.envOr("DEFAULT_FEE", uint256(3000)));
        
        // Load governance address (use deployer if not set)
        try vm.envAddress("GOVERNANCE_ADDRESS") returns (address gov) {
            governance = gov;
        } catch {
            governance = vm.addr(vm.envUint("PRIVATE_KEY"));
            console.log("Using deployer as governance address");
        }
        
        // Load hook manager address (use governance if not set)
        try vm.envAddress("HOOK_MANAGER_ADDRESS") returns (address manager) {
            hookManager = manager;
        } catch {
            hookManager = governance;
            console.log("Using governance as hook manager address");
        }
        
        // Load hook management setting
        enableHookManagement = vm.envOr("ENABLE_HOOK_MANAGEMENT", true);
        
        // Load or generate salt
        try vm.envBytes32("DEPLOYMENT_SALT") returns (bytes32 envSalt) {
            salt = keccak256(abi.encodePacked(envSalt, "permissioned"));
        } catch {
            salt = keccak256(abi.encodePacked("permissioned-adapter-", block.timestamp));
        }
    }

    function _validateConfiguration() internal view {
        require(factoryAddress != address(0), "Invalid factory address");
        require(address(poolManager) != address(0), "Invalid pool manager address");
        require(governance != address(0), "Invalid governance address");
        require(hookManager != address(0), "Invalid hook manager address");
        require(defaultFee <= 1000000, "Default fee too high (max 100%)");
    }

    function _verifyDeployment() internal view {
        // Verify adapter was deployed correctly
        require(address(adapter) != address(0), "Adapter deployment failed");
        require(address(adapter).code.length > 0, "Adapter has no code");
        
        // Verify adapter configuration
        require(address(adapter.poolManager()) == address(poolManager), "Pool manager mismatch");
        require(adapter.governance() == governance, "Governance mismatch");
        require(adapter.hookManager() == hookManager, "Hook manager mismatch");
        require(adapter.hookManagementEnabled() == enableHookManagement, "Hook management setting mismatch");
        
        console.log("Deployment verification passed [OK]");
    }

    function _saveDeploymentInfo() internal {
        string memory info = string.concat(
            "# Permissioned MultiHookAdapter Deployment\n",
            "# Network: ", vm.toString(block.chainid), "\n",
            "# Block: ", vm.toString(block.number), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "PERMISSIONED_ADAPTER_ADDRESS=", vm.toString(address(adapter)), "\n",
            "POOL_MANAGER=", vm.toString(address(poolManager)), "\n",
            "DEFAULT_FEE=", vm.toString(defaultFee), "\n",
            "GOVERNANCE_ADDRESS=", vm.toString(governance), "\n",
            "HOOK_MANAGER_ADDRESS=", vm.toString(hookManager), "\n",
            "HOOK_MANAGEMENT_ENABLED=", enableHookManagement ? "true" : "false", "\n",
            "DEPLOYMENT_SALT=", vm.toString(salt), "\n"
        );
        
        string memory filename = string.concat("permissioned-adapter-", vm.toString(block.chainid), ".env");
        vm.writeFile(filename, info);
        console.log("Deployment info saved to:", filename);
    }

    function _printNextSteps() internal view {
        console.log("================================");
        console.log("NEXT STEPS:");
        console.log("================================");
        console.log("1. Approve hooks using hookManager account:");
        console.log("   adapter.approveHook(hookAddress)");
        console.log("");
        console.log("2. Register hooks for pools:");
        console.log("   adapter.registerHooks(poolKey, hookAddresses)");
        console.log("");
        console.log("3. Configure fee calculation methods:");
        console.log("   adapter.setPoolFeeCalculationMethod(poolId, method)");
        console.log("");
        console.log("4. Set pool-specific fees if needed:");
        console.log("   adapter.setPoolSpecificFee(poolId, fee)");
        console.log("================================");
        if (governance != hookManager) {
            console.log("Note: Governance and hook manager are different addresses.");
            console.log("Ensure proper coordination between roles.");
        }
    }

    // Helper function to extract values from .env file content
    function _extractValue(string memory content, string memory key) internal pure returns (string memory) {
        bytes memory contentBytes = bytes(content);
        bytes memory keyBytes = bytes(string.concat(key, "="));
        
        for (uint256 i = 0; i <= contentBytes.length - keyBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < keyBytes.length; j++) {
                if (contentBytes[i + j] != keyBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                uint256 start = i + keyBytes.length;
                uint256 end = start;
                while (end < contentBytes.length && contentBytes[end] != '\n') {
                    end++;
                }
                bytes memory valueBytes = new bytes(end - start);
                for (uint256 k = 0; k < end - start; k++) {
                    valueBytes[k] = contentBytes[start + k];
                }
                return string(valueBytes);
            }
        }
        revert(string.concat("Key not found: ", key));
    }
}