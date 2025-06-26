# MultiHookAdapter Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the MultiHookAdapter system to testnet and mainnet networks. The deployment consists of a modular factory system optimized for Ethereum's contract size limits.

## Prerequisites

### Required Tools
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, anvil, cast)
- Git
- Node.js (for npm scripts, optional)

### Required Information
- Private key for deployment account
- RPC URL for target network
- Etherscan API key (optional, for contract verification)
- Uniswap V4 PoolManager address (when available)

## Quick Start (Testnet)

### 1. Environment Setup

```bash
# Clone and setup
cd multihook-adapter
forge install

# Copy environment template
cp .env.template .env

# Edit .env with your configuration
# Required: PRIVATE_KEY, SEPOLIA_RPC_URL
# Optional: ETHERSCAN_API_KEY
```

### 2. Deploy Factory System

```bash
# Easy deployment script
./scripts/deploy-testnet.sh

# Or manual deployment
forge script scripts/DeployFactory.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

### 3. Verify Deployment

```bash
forge script scripts/VerifyDeployment.s.sol --rpc-url $SEPOLIA_RPC_URL
```

## Detailed Deployment Process

### Phase 1: Factory System Deployment

The factory system consists of four contracts deployed in sequence:

1. **BasicAdapterFactory** (1,767 bytes) - Deploys immutable adapters
2. **PermissionedAdapterFactory** (1,358 bytes) - Deploys governance-controlled adapters
3. **MultiHookAdapterFactory** (1,441 bytes) - Main coordinator factory
4. **AdapterDeploymentHelper** (4,257 bytes) - High-level deployment workflows

```bash
# Deploy factory system
forge script scripts/DeployFactory.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

Expected output:
```
BasicAdapterFactory deployed at: 0x...
PermissionedAdapterFactory deployed at: 0x...
MultiHookAdapterFactory deployed at: 0x...
AdapterDeploymentHelper deployed at: 0x...
```

### Phase 2: Adapter Deployment

Once the factory system is deployed, you can deploy specific adapter instances:

#### Deploy Basic (Immutable) Adapter

```bash
forge script scripts/DeployBasicAdapter.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast
```

#### Deploy Permissioned Adapter

```bash
forge script scripts/DeployPermissionedAdapter.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast
```

#### Advanced Deployment with Helper

```bash
forge script scripts/DeployWithHelper.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast
```

### Phase 3: Verification and Testing

```bash
# Verify deployment integrity
forge script scripts/VerifyDeployment.s.sol --rpc-url $SEPOLIA_RPC_URL

# Run integration tests
forge test --rpc-url $SEPOLIA_RPC_URL
```

## Environment Configuration

### .env File Structure

```bash
# Required for deployment
PRIVATE_KEY=your_private_key_without_0x_prefix
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
ETHERSCAN_API_KEY=your_etherscan_api_key

# Optional configuration
DEFAULT_FEE=3000                    # 0.3% default fee
GOVERNANCE_ADDRESS=0x...            # Custom governance address
HOOK_MANAGER_ADDRESS=0x...          # Custom hook manager address
DEPLOYMENT_SALT=0x...               # Custom deployment salt

# Network-specific PoolManager addresses (update when available)
SEPOLIA_POOL_MANAGER=0x...
MAINNET_POOL_MANAGER=0x...
```

### RPC Provider Options

#### Infura
```bash
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID
```

#### Alchemy
```bash
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
```

#### QuickNode
```bash
SEPOLIA_RPC_URL=https://your-endpoint.sepolia.quiknode.pro/your-token/
MAINNET_RPC_URL=https://your-endpoint.ethereum.quiknode.pro/your-token/
```

## Contract Addresses

### Sepolia Testnet
```
Network: Sepolia (Chain ID: 11155111)
BasicAdapterFactory: TBD
PermissionedAdapterFactory: TBD  
MultiHookAdapterFactory: TBD
AdapterDeploymentHelper: TBD
```

### Ethereum Mainnet
```
Network: Mainnet (Chain ID: 1)
BasicAdapterFactory: TBD
PermissionedAdapterFactory: TBD
MultiHookAdapterFactory: TBD
AdapterDeploymentHelper: TBD
```

*Addresses will be updated after deployment*

## Deployment Scripts Reference

### Core Scripts

| Script | Purpose | Gas Usage | Verification |
|--------|---------|-----------|--------------|
| `DeployFactory.s.sol` | Deploy complete factory system | ~2.5M gas | Auto-verify |
| `DeployBasicAdapter.s.sol` | Deploy immutable adapter | ~1.2M gas | Manual |
| `DeployPermissionedAdapter.s.sol` | Deploy governance adapter | ~1.5M gas | Manual |
| `DeployWithHelper.s.sol` | Advanced deployment workflows | Variable | Manual |
| `VerifyDeployment.s.sol` | Validate all deployments | Read-only | N/A |

### Utility Scripts

| Script | Purpose |
|--------|---------|
| `deploy-testnet.sh` | Complete testnet deployment |
| `deploy-mainnet.sh` | Complete mainnet deployment (coming soon) |

## Gas Optimization

### Deployment Gas Costs (Sepolia)

| Contract | Deployment Gas | USD (20 gwei, $2000 ETH) |
|----------|----------------|---------------------------|
| BasicAdapterFactory | ~400k gas | ~$16 |
| PermissionedAdapterFactory | ~350k gas | ~$14 |
| MultiHookAdapterFactory | ~300k gas | ~$12 |
| AdapterDeploymentHelper | ~500k gas | ~$20 |
| **Total Factory System** | **~1.55M gas** | **~$62** |

### Per-Adapter Deployment

| Adapter Type | Gas Cost | USD (20 gwei, $2000 ETH) |
|--------------|----------|---------------------------|
| Basic Adapter | ~1.2M gas | ~$48 |
| Permissioned Adapter | ~1.5M gas | ~$60 |

## Post-Deployment Setup

### 1. Configure Permissioned Adapters

```solidity
// Approve hooks (as hook manager)
adapter.approveHook(hookAddress);

// Batch approve multiple hooks
address[] memory hooks = [hook1, hook2, hook3];
adapter.batchApproveHooks(hooks);
```

### 2. Register Hooks for Pools

```solidity
// Register hooks for a specific pool
PoolKey memory poolKey = PoolKey({...});
address[] memory poolHooks = [hook1, hook2];
adapter.registerHooks(poolKey, poolHooks);
```

### 3. Configure Fee Strategies

```solidity
// Set fee calculation method for a pool
adapter.setPoolFeeCalculationMethod(
    poolId, 
    IFeeCalculationStrategy.FeeCalculationMethod.MEDIAN
);

// Set pool-specific fee override
adapter.setPoolSpecificFee(poolId, 2500); // 0.25%
```

## Security Considerations

### Private Key Management
- Never commit private keys to version control
- Use hardware wallets for mainnet deployments
- Consider using multiple signatures for governance functions

### Contract Verification
- Always verify contracts on Etherscan
- Compare deployed bytecode with compiled bytecode
- Verify constructor parameters

### Address Validation
- Double-check all addresses before deployment
- Verify PoolManager address is correct for the network
- Ensure governance addresses are properly controlled

## Troubleshooting

### Common Issues

#### "Contract size exceeds limit"
- All contracts are optimized and should be under 24KB
- If this occurs, check for compiler version mismatch

#### "Address prediction mismatch"
- Ensure salt is unique across deployments
- Verify constructor parameters match prediction call

#### "Factory reference mismatch"
- Deploy factories in correct order
- Verify factory addresses in deployment file

#### "Transaction reverted"
- Check gas limit (use 8M gas limit for safety)
- Verify all constructor parameters
- Ensure sufficient ETH balance

### Debug Commands

```bash
# Check contract size
forge build --sizes | grep Factory

# Simulate deployment without broadcasting
forge script scripts/DeployFactory.s.sol --rpc-url $SEPOLIA_RPC_URL

# Check deployment file
cat deployments-11155111.env

# Verify specific contract
forge verify-contract $CONTRACT_ADDRESS $CONTRACT_PATH --chain sepolia
```

## Mainnet Deployment (Coming Soon)

Mainnet deployment will follow the same process with additional security measures:

1. **Multi-signature governance setup**
2. **Time-locked deployments**
3. **Comprehensive security audits**
4. **Community governance proposals**

## Support

For deployment issues or questions:

1. Check this documentation
2. Review the test suite for examples
3. Open an issue on GitHub
4. Join the community Discord

## Changelog

### v1.0.0 - Initial Release
- Complete factory system
- Contract size optimization
- Comprehensive testing (241 tests)
- Production-ready deployment scripts