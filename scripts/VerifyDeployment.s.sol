// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MultiHookAdapterFactory} from "../src/factory/MultiHookAdapterFactory.sol";
import {BasicAdapterFactory} from "../src/factory/BasicAdapterFactory.sol";
import {PermissionedAdapterFactory} from "../src/factory/PermissionedAdapterFactory.sol";
import {AdapterDeploymentHelper} from "../src/factory/AdapterDeploymentHelper.sol";
import {MultiHookAdapter} from "../src/MultiHookAdapter.sol";
import {PermissionedMultiHookAdapter} from "../src/PermissionedMultiHookAdapter.sol";

/**
 * @title VerifyDeployment
 * @notice Script to verify all deployed contracts are working correctly
 * @dev This script performs comprehensive verification of the deployment:
 *      - Contract size limits
 *      - Factory functionality
 *      - Address predictions
 *      - Contract interactions
 */
contract VerifyDeployment is Script {
    // Contract addresses to verify
    address public basicFactory;
    address public permissionedFactory;
    address public mainFactory;
    address public deploymentHelper;
    
    // Test deployment addresses
    address public testBasicAdapter;
    address public testPermissionedAdapter;

    function run() external {
        console.log("================================");
        console.log("MultiHookAdapter Deployment Verification");
        console.log("================================");
        console.log("Network:", block.chainid);
        console.log("Block:", block.number);
        console.log("================================");

        _loadAddresses();
        _verifyContracts();
        _verifyFactoryFunctionality();
        _verifyContractSizes();
        _performIntegrationTests();
        
        console.log("================================");
        console.log("VERIFICATION COMPLETE!");
        console.log("All contracts verified successfully [OK]");
        console.log("================================");
    }

    function _loadAddresses() internal {
        console.log("Loading deployment addresses...");
        
        try vm.readFile(string.concat("deployments-", vm.toString(block.chainid), ".env")) returns (string memory content) {
            basicFactory = vm.parseAddress(_extractValue(content, "BASIC_ADAPTER_FACTORY"));
            permissionedFactory = vm.parseAddress(_extractValue(content, "PERMISSIONED_ADAPTER_FACTORY"));
            mainFactory = vm.parseAddress(_extractValue(content, "MULTI_HOOK_ADAPTER_FACTORY"));
            deploymentHelper = vm.parseAddress(_extractValue(content, "ADAPTER_DEPLOYMENT_HELPER"));
            
            console.log("BasicAdapterFactory:", basicFactory);
            console.log("PermissionedAdapterFactory:", permissionedFactory);
            console.log("MultiHookAdapterFactory:", mainFactory);
            console.log("AdapterDeploymentHelper:", deploymentHelper);
        } catch {
            revert("Deployment file not found. Deploy contracts first.");
        }
    }

    function _verifyContracts() internal view {
        console.log("Verifying contract deployments...");
        
        require(basicFactory != address(0), "BasicAdapterFactory address is zero");
        require(permissionedFactory != address(0), "PermissionedAdapterFactory address is zero");
        require(mainFactory != address(0), "MultiHookAdapterFactory address is zero");
        require(deploymentHelper != address(0), "AdapterDeploymentHelper address is zero");
        
        require(basicFactory.code.length > 0, "BasicAdapterFactory has no code");
        require(permissionedFactory.code.length > 0, "PermissionedAdapterFactory has no code");
        require(mainFactory.code.length > 0, "MultiHookAdapterFactory has no code");
        require(deploymentHelper.code.length > 0, "AdapterDeploymentHelper has no code");
        
        console.log("Contract deployments verified [OK]");
    }

    function _verifyFactoryFunctionality() internal view {
        console.log("Verifying factory functionality...");
        
        MultiHookAdapterFactory factory = MultiHookAdapterFactory(mainFactory);
        
        // Verify factory references
        require(factory.basicFactory() == basicFactory, "BasicFactory reference mismatch");
        require(factory.permissionedFactory() == permissionedFactory, "PermissionedFactory reference mismatch");
        
        AdapterDeploymentHelper helper = AdapterDeploymentHelper(deploymentHelper);
        require(helper.factory() == mainFactory, "Factory reference in helper mismatch");
        
        console.log("Factory functionality verified [OK]");
    }

    function _verifyContractSizes() internal view {
        console.log("Verifying contract sizes...");
        
        uint256 basicFactorySize = basicFactory.code.length;
        uint256 permissionedFactorySize = permissionedFactory.code.length;
        uint256 mainFactorySize = mainFactory.code.length;
        uint256 helperSize = deploymentHelper.code.length;
        
        console.log("BasicAdapterFactory size:", basicFactorySize, "bytes");
        console.log("PermissionedAdapterFactory size:", permissionedFactorySize, "bytes");
        console.log("MultiHookAdapterFactory size:", mainFactorySize, "bytes");
        console.log("AdapterDeploymentHelper size:", helperSize, "bytes");
        
        require(basicFactorySize <= 24576, "BasicAdapterFactory exceeds size limit");
        require(permissionedFactorySize <= 24576, "PermissionedAdapterFactory exceeds size limit");
        require(mainFactorySize <= 24576, "MultiHookAdapterFactory exceeds size limit");
        require(helperSize <= 24576, "AdapterDeploymentHelper exceeds size limit");
        
        console.log("Contract sizes verified [OK]");
    }

    function _performIntegrationTests() internal {
        console.log("Performing integration tests...");
        
        // Note: These tests require a valid PoolManager address
        // For now, we'll test address prediction functionality
        _testAddressPrediction();
        
        console.log("Integration tests completed [OK]");
    }

    function _testAddressPrediction() internal view {
        console.log("Testing address prediction...");
        
        MultiHookAdapterFactory factory = MultiHookAdapterFactory(mainFactory);
        
        // Test parameters
        address mockPoolManager = address(0x1234567890123456789012345678901234567890);
        uint24 testFee = 3000;
        bytes32 testSalt = keccak256("test-prediction");
        address testGovernance = address(0x1111111111111111111111111111111111111111);
        address testHookManager = address(0x2222222222222222222222222222222222222222);
        
        // Test basic adapter address prediction
        address predictedBasic = factory.predictMultiHookAdapterAddress(
            mockPoolManager,
            testFee,
            testSalt
        );
        require(predictedBasic != address(0), "Basic adapter prediction failed");
        console.log("Basic adapter prediction:", predictedBasic);
        
        // Test permissioned adapter address prediction
        address predictedPermissioned = factory.predictPermissionedMultiHookAdapterAddress(
            mockPoolManager,
            testFee,
            testGovernance,
            testHookManager,
            true,
            testSalt
        );
        require(predictedPermissioned != address(0), "Permissioned adapter prediction failed");
        require(predictedBasic != predictedPermissioned, "Predictions should be different");
        console.log("Permissioned adapter prediction:", predictedPermissioned);
        
        console.log("Address prediction tests passed [OK]");
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