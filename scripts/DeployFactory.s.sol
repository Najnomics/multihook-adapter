// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MultiHookAdapterFactory} from "../src/factory/MultiHookAdapterFactory.sol";
import {BasicAdapterFactory} from "../src/factory/BasicAdapterFactory.sol";
import {PermissionedAdapterFactory} from "../src/factory/PermissionedAdapterFactory.sol";
import {AdapterDeploymentHelper} from "../src/factory/AdapterDeploymentHelper.sol";

/**
 * @title DeployFactory
 * @notice Deployment script for the MultiHookAdapter factory system
 * @dev This script deploys the complete factory infrastructure:
 *      1. BasicAdapterFactory - for immutable adapters
 *      2. PermissionedAdapterFactory - for governance-controlled adapters  
 *      3. MultiHookAdapterFactory - main coordinator factory
 *      4. AdapterDeploymentHelper - high-level deployment workflows
 */
contract DeployFactory is Script {
    // Deployment addresses will be stored here
    BasicAdapterFactory public basicFactory;
    PermissionedAdapterFactory public permissionedFactory;
    MultiHookAdapterFactory public mainFactory;
    AdapterDeploymentHelper public deploymentHelper;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("================================");
        console.log("MultiHookAdapter Factory Deployment");
        console.log("================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("================================");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy MultiHookAdapterFactory (which creates the other factories internally)
        console.log("Step 1: Deploying MultiHookAdapterFactory with internal factories...");
        mainFactory = new MultiHookAdapterFactory();
        console.log("MultiHookAdapterFactory deployed at:", address(mainFactory));
        
        // Get references to the automatically created factories
        basicFactory = BasicAdapterFactory(address(mainFactory.basicFactory()));
        permissionedFactory = PermissionedAdapterFactory(address(mainFactory.permissionedFactory()));
        console.log("BasicAdapterFactory created at:", address(basicFactory));
        console.log("PermissionedAdapterFactory created at:", address(permissionedFactory));
        
        // Verify contract sizes for the main factory
        uint256 mainFactorySize = address(mainFactory).code.length;
        console.log("MultiHookAdapterFactory size:", mainFactorySize, "bytes");
        require(mainFactorySize <= 24576, "MultiHookAdapterFactory exceeds contract size limit");

        // Step 2: Deploy AdapterDeploymentHelper
        console.log("Step 2: Deploying AdapterDeploymentHelper...");
        deploymentHelper = new AdapterDeploymentHelper(mainFactory);
        console.log("AdapterDeploymentHelper deployed at:", address(deploymentHelper));
        
        // Verify contract sizes for all components
        uint256 basicFactorySize = address(basicFactory).code.length;
        uint256 permissionedFactorySize = address(permissionedFactory).code.length;
        uint256 helperSize = address(deploymentHelper).code.length;
        console.log("BasicAdapterFactory size:", basicFactorySize, "bytes");
        console.log("PermissionedAdapterFactory size:", permissionedFactorySize, "bytes");
        console.log("AdapterDeploymentHelper size:", helperSize, "bytes");
        require(basicFactorySize <= 24576, "BasicAdapterFactory exceeds contract size limit");
        require(permissionedFactorySize <= 24576, "PermissionedAdapterFactory exceeds contract size limit");
        require(helperSize <= 24576, "AdapterDeploymentHelper exceeds contract size limit");

        vm.stopBroadcast();

        // Step 5: Deployment Summary
        console.log("================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("================================");
        console.log("MultiHookAdapterFactory:", address(mainFactory));
        console.log("BasicAdapterFactory:", address(basicFactory));
        console.log("PermissionedAdapterFactory:", address(permissionedFactory));
        console.log("AdapterDeploymentHelper:", address(deploymentHelper));
        console.log("================================");
        console.log("Total contracts deployed: 4");
        console.log("All contracts are under 24KB limit [OK]");
        console.log("================================");

        // Step 6: Verify factory references
        console.log("Verifying factory references...");
        require(address(mainFactory.basicFactory()) == address(basicFactory), "BasicFactory reference mismatch");
        require(address(mainFactory.permissionedFactory()) == address(permissionedFactory), "PermissionedFactory reference mismatch");
        require(address(deploymentHelper.factory()) == address(mainFactory), "MainFactory reference mismatch");
        console.log("Factory references verified [OK]");

        // Save deployment addresses to file (if permissions allow)
        _saveDeploymentAddresses();
    }

    function _saveDeploymentAddresses() internal {
        console.log("================================");
        console.log("DEPLOYMENT ADDRESSES (Copy for .env file)");
        console.log("================================");
        console.log("MULTI_HOOK_ADAPTER_FACTORY=", vm.toString(address(mainFactory)));
        console.log("BASIC_ADAPTER_FACTORY=", vm.toString(address(basicFactory)));
        console.log("PERMISSIONED_ADAPTER_FACTORY=", vm.toString(address(permissionedFactory)));
        console.log("ADAPTER_DEPLOYMENT_HELPER=", vm.toString(address(deploymentHelper)));
        console.log("================================");
    }
}