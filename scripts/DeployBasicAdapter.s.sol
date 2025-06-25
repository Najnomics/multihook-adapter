// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {MultiHookAdapterFactory} from "../src/factory/MultiHookAdapterFactory.sol";
import {MultiHookAdapter} from "../src/MultiHookAdapter.sol";

/**
 * @title DeployBasicAdapter
 * @notice Deployment script for basic (immutable) MultiHookAdapter instances
 * @dev This script demonstrates deploying a basic adapter with predetermined configuration
 */
contract DeployBasicAdapter is Script {
    // Factory address (will be loaded from environment or previous deployment)
    address public factoryAddress;
    
    // Deployment parameters
    IPoolManager public poolManager;
    uint24 public defaultFee;
    bytes32 public salt;
    
    // Deployed adapter
    MultiHookAdapter public adapter;

    function run() external {
        _loadConfiguration();
        _validateConfiguration();
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("================================");
        console.log("Basic MultiHookAdapter Deployment");
        console.log("================================");
        console.log("Deployer:", deployer);
        console.log("Factory:", factoryAddress);
        console.log("Pool Manager:", address(poolManager));
        console.log("Default Fee:", defaultFee);
        console.log("Salt:", vm.toString(salt));
        console.log("================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the adapter
        console.log("Deploying MultiHookAdapter...");
        MultiHookAdapterFactory factory = MultiHookAdapterFactory(factoryAddress);
        
        // Predict the address first
        address predictedAddress = factory.predictMultiHookAdapterAddress(
            poolManager,
            defaultFee,
            salt
        );
        console.log("Predicted address:", predictedAddress);

        // Deploy the adapter
        address deployedAddress = factory.deployMultiHookAdapter(
            poolManager,
            defaultFee,
            salt
        );
        
        adapter = MultiHookAdapter(deployedAddress);
        console.log("MultiHookAdapter deployed at:", deployedAddress);
        
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
        console.log("MultiHookAdapter:", address(adapter));
        console.log("================================");
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
        
        // Load or generate salt
        try vm.envBytes32("DEPLOYMENT_SALT") returns (bytes32 envSalt) {
            salt = envSalt;
        } catch {
            salt = keccak256(abi.encodePacked("basic-adapter-", block.timestamp));
        }
    }

    function _validateConfiguration() internal view {
        require(factoryAddress != address(0), "Invalid factory address");
        require(address(poolManager) != address(0), "Invalid pool manager address");
        require(defaultFee <= 1000000, "Default fee too high (max 100%)");
    }

    function _verifyDeployment() internal view {
        // Verify adapter was deployed correctly
        require(address(adapter) != address(0), "Adapter deployment failed");
        require(address(adapter).code.length > 0, "Adapter has no code");
        
        // Verify adapter configuration
        require(address(adapter.poolManager()) == address(poolManager), "Pool manager mismatch");
        
        console.log("Deployment verification passed [OK]");
    }

    function _saveDeploymentInfo() internal {
        string memory info = string.concat(
            "# Basic MultiHookAdapter Deployment\n",
            "# Network: ", vm.toString(block.chainid), "\n",
            "# Block: ", vm.toString(block.number), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "BASIC_ADAPTER_ADDRESS=", vm.toString(address(adapter)), "\n",
            "POOL_MANAGER=", vm.toString(address(poolManager)), "\n",
            "DEFAULT_FEE=", vm.toString(defaultFee), "\n",
            "DEPLOYMENT_SALT=", vm.toString(salt), "\n"
        );
        
        string memory filename = string.concat("basic-adapter-", vm.toString(block.chainid), ".env");
        vm.writeFile(filename, info);
        console.log("Deployment info saved to:", filename);
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