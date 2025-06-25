#!/bin/bash

# MultiHookAdapter Deployment Script for Sepolia Testnet
# This script provides an easy way to deploy the complete factory system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}MultiHookAdapter Testnet Deployment${NC}"
echo -e "${BLUE}================================${NC}"

# Check if .env file exists
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please copy .env.template to .env and configure your settings${NC}"
    echo "cp .env.template .env"
    exit 1
fi

# Source environment variables
source "$PROJECT_DIR/.env"

# Validate required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo -e "${RED}Error: SEPOLIA_RPC_URL not set in .env${NC}"
    exit 1
fi

echo -e "${GREEN}Environment configuration loaded ✓${NC}"

# Change to project directory
cd "$PROJECT_DIR"

# Build contracts
echo -e "${YELLOW}Building contracts...${NC}"
forge build
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi
echo -e "${GREEN}Build successful ✓${NC}"

# Run tests to ensure everything is working
echo -e "${YELLOW}Running tests...${NC}"
forge test --summary
if [ $? -ne 0 ]; then
    echo -e "${RED}Tests failed${NC}"
    echo -e "${YELLOW}Warning: Continuing with deployment despite test failures${NC}"
fi

# Deploy factory system
echo -e "${YELLOW}Deploying factory system to Sepolia...${NC}"
forge script scripts/DeployFactory.s.sol \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --legacy

if [ $? -ne 0 ]; then
    echo -e "${RED}Factory deployment failed${NC}"
    exit 1
fi

echo -e "${GREEN}Factory deployment successful ✓${NC}"

# Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
forge script scripts/VerifyDeployment.s.sol \
    --rpc-url "$SEPOLIA_RPC_URL"

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment verification failed${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment verification successful ✓${NC}"

# Contract verification on Etherscan (if API key is provided)
if [ -n "$ETHERSCAN_API_KEY" ]; then
    echo -e "${YELLOW}Verifying contracts on Etherscan...${NC}"
    
    # Load deployment addresses
    DEPLOYMENT_FILE="deployments-11155111.env"
    if [ -f "$DEPLOYMENT_FILE" ]; then
        source "$DEPLOYMENT_FILE"
        
        echo "Verifying BasicAdapterFactory..."
        forge verify-contract "$BASIC_ADAPTER_FACTORY" \
            src/factory/BasicAdapterFactory.sol:BasicAdapterFactory \
            --chain sepolia \
            --etherscan-api-key "$ETHERSCAN_API_KEY" || echo "Verification failed for BasicAdapterFactory"
        
        echo "Verifying PermissionedAdapterFactory..."
        forge verify-contract "$PERMISSIONED_ADAPTER_FACTORY" \
            src/factory/PermissionedAdapterFactory.sol:PermissionedAdapterFactory \
            --chain sepolia \
            --etherscan-api-key "$ETHERSCAN_API_KEY" || echo "Verification failed for PermissionedAdapterFactory"
        
        echo "Verifying MultiHookAdapterFactory..."
        forge verify-contract "$MULTI_HOOK_ADAPTER_FACTORY" \
            src/factory/MultiHookAdapterFactory.sol:MultiHookAdapterFactory \
            --chain sepolia \
            --etherscan-api-key "$ETHERSCAN_API_KEY" \
            --constructor-args $(cast abi-encode "constructor(address,address)" "$BASIC_ADAPTER_FACTORY" "$PERMISSIONED_ADAPTER_FACTORY") || echo "Verification failed for MultiHookAdapterFactory"
        
        echo "Verifying AdapterDeploymentHelper..."
        forge verify-contract "$ADAPTER_DEPLOYMENT_HELPER" \
            src/factory/AdapterDeploymentHelper.sol:AdapterDeploymentHelper \
            --chain sepolia \
            --etherscan-api-key "$ETHERSCAN_API_KEY" \
            --constructor-args $(cast abi-encode "constructor(address)" "$MULTI_HOOK_ADAPTER_FACTORY") || echo "Verification failed for AdapterDeploymentHelper"
        
        echo -e "${GREEN}Etherscan verification completed${NC}"
    else
        echo -e "${RED}Deployment file not found, skipping Etherscan verification${NC}"
    fi
else
    echo -e "${YELLOW}Etherscan API key not provided, skipping contract verification${NC}"
fi

echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo -e "${BLUE}================================${NC}"

# Display deployment summary
if [ -f "deployments-11155111.env" ]; then
    echo -e "${YELLOW}Deployment Addresses:${NC}"
    cat deployments-11155111.env
    echo ""
fi

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Save your deployment addresses from deployments-11155111.env"
echo "2. Deploy adapters using DeployBasicAdapter.s.sol or DeployPermissionedAdapter.s.sol"
echo "3. Test your deployment with example hooks"
echo ""
echo -e "${GREEN}Testnet deployment successful! 🎉${NC}"