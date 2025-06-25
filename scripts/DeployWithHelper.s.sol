// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {AdapterDeploymentHelper} from "../src/factory/AdapterDeploymentHelper.sol";
import {IFeeCalculationStrategy} from "../src/interfaces/IFeeCalculationStrategy.sol";

/**
 * @title DeployWithHelper
 * @notice Comprehensive deployment script using AdapterDeploymentHelper
 * @dev This script demonstrates advanced deployment workflows including:
 *      - Deploying adapters with hooks pre-registered
 *      - Setting up fee configurations
 *      - Batch deployments
 *      - Complete pool setup
 */
contract DeployWithHelper is Script {
    // Helper address
    address public helperAddress;
    
    // Example deployment configuration
    IPoolManager public poolManager;
    uint24 public defaultFee = 3000;
    
    // Example pool configuration
    PoolKey public examplePoolKey;
    address[] public exampleHooks;
    
    // Deployed contracts
    address public deployedAdapter;
    address public deployedPermissionedAdapter;

    function run() external {
        _loadConfiguration();
        _setupExampleConfiguration();
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("================================");
        console.log("Advanced Deployment with Helper");
        console.log("================================");
        console.log("Deployer:", deployer);
        console.log("Helper:", helperAddress);
        console.log("Pool Manager:", address(poolManager));
        console.log("================================");

        vm.startBroadcast(deployerPrivateKey);

        AdapterDeploymentHelper helper = AdapterDeploymentHelper(helperAddress);

        // Example 1: Deploy and register hooks in one transaction
        console.log("Example 1: Deploy adapter with hooks...");
        deployedAdapter = helper.deployAndRegisterHooks(
            poolManager,
            defaultFee,
            examplePoolKey,
            exampleHooks,
            keccak256("example-1")
        );
        console.log("Adapter with hooks deployed:", deployedAdapter);

        // Example 2: Deploy with full fee configuration
        console.log("Example 2: Deploy with full fee config...");
        address adapterWithFeeConfig = helper.deployWithFullFeeConfig(
            poolManager,
            defaultFee,
            examplePoolKey,
            exampleHooks,
            IFeeCalculationStrategy.FeeCalculationMethod.MEDIAN,
            2500, // 0.25% pool-specific fee
            keccak256("example-2")
        );
        console.log("Adapter with fee config deployed:", adapterWithFeeConfig);

        // Example 3: Deploy permissioned adapter with setup
        console.log("Example 3: Deploy permissioned adapter...");
        deployedPermissionedAdapter = helper.deployPermissionedWithSetup(
            poolManager,
            defaultFee,
            deployer, // governance
            deployer, // hook manager
            exampleHooks,
            keccak256("example-3")
        );
        console.log("Permissioned adapter deployed:", deployedPermissionedAdapter);

        vm.stopBroadcast();

        // Verify deployments
        _verifyDeployments();
        
        // Save deployment information
        _saveDeploymentSummary();
        
        console.log("================================");
        console.log("ADVANCED DEPLOYMENT COMPLETE!");
        console.log("================================");
    }

    function _loadConfiguration() internal {
        // Load helper address
        try vm.envAddress("ADAPTER_DEPLOYMENT_HELPER") returns (address helper) {
            helperAddress = helper;
        } catch {
            try vm.readFile(string.concat("deployments-", vm.toString(block.chainid), ".env")) returns (string memory content) {
                helperAddress = vm.parseAddress(_extractValue(content, "ADAPTER_DEPLOYMENT_HELPER"));
            } catch {
                revert("Helper address not found. Deploy factory system first.");
            }
        }
        
        // Load pool manager
        string memory poolManagerKey = string.concat(
            block.chainid == 11155111 ? "SEPOLIA" : "MAINNET",
            "_POOL_MANAGER"
        );
        poolManager = IPoolManager(vm.envAddress(poolManagerKey));
    }

    function _setupExampleConfiguration() internal {
        // Set up example pool key
        examplePoolKey = PoolKey({
            currency0: Currency.wrap(address(0x1111111111111111111111111111111111111111)),
            currency1: Currency.wrap(address(0x2222222222222222222222222222222222222222)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0)) // Will be set to deployed adapter
        });
        
        // Set up example hooks (these would be real hook addresses in production)
        exampleHooks.push(address(0x3333333333333333333333333333333333333333)); // Example TWAMM hook
        exampleHooks.push(address(0x4444444444444444444444444444444444444444)); // Example Oracle hook
        exampleHooks.push(address(0x5555555555555555555555555555555555555555)); // Example MEV protection hook
        
        console.log("Example configuration:");
        console.log("Pool Currency0:", Currency.unwrap(examplePoolKey.currency0));
        console.log("Pool Currency1:", Currency.unwrap(examplePoolKey.currency1));
        console.log("Pool Fee:", examplePoolKey.fee);
        console.log("Pool Tick Spacing:", examplePoolKey.tickSpacing);
        console.log("Number of example hooks:", exampleHooks.length);
    }

    function _verifyDeployments() internal view {
        console.log("Verifying deployments...");
        
        require(deployedAdapter != address(0), "Basic adapter deployment failed");
        require(deployedPermissionedAdapter != address(0), "Permissioned adapter deployment failed");
        require(deployedAdapter.code.length > 0, "Basic adapter has no code");
        require(deployedPermissionedAdapter.code.length > 0, "Permissioned adapter has no code");
        
        console.log("Deployment verification passed [OK]");
    }

    function _saveDeploymentSummary() internal {
        string memory summary = string.concat(
            "# Advanced Deployment Summary\n",
            "# Network: ", vm.toString(block.chainid), "\n",
            "# Block: ", vm.toString(block.number), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "EXAMPLE_BASIC_ADAPTER=", vm.toString(deployedAdapter), "\n",
            "EXAMPLE_PERMISSIONED_ADAPTER=", vm.toString(deployedPermissionedAdapter), "\n",
            "POOL_MANAGER=", vm.toString(address(poolManager)), "\n",
            "DEFAULT_FEE=", vm.toString(defaultFee), "\n\n",
            "# Example Pool Configuration\n",
            "POOL_CURRENCY0=", vm.toString(Currency.unwrap(examplePoolKey.currency0)), "\n",
            "POOL_CURRENCY1=", vm.toString(Currency.unwrap(examplePoolKey.currency1)), "\n",
            "POOL_FEE=", vm.toString(examplePoolKey.fee), "\n",
            "POOL_TICK_SPACING=", vm.toString(examplePoolKey.tickSpacing), "\n\n",
            "# Example Hooks\n"
        );
        
        for (uint256 i = 0; i < exampleHooks.length; i++) {
            summary = string.concat(
                summary,
                "EXAMPLE_HOOK_", vm.toString(i), "=", vm.toString(exampleHooks[i]), "\n"
            );
        }
        
        string memory filename = string.concat("advanced-deployment-", vm.toString(block.chainid), ".env");
        vm.writeFile(filename, summary);
        console.log("Deployment summary saved to:", filename);
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