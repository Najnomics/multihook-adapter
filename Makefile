# MultiHookAdapter Deployment Makefile

# Default network (sepolia)
NETWORK ?= sepolia

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Colors for output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# RPC URL based on network
ifeq ($(NETWORK),sepolia)
    RPC_URL := $(SEPOLIA_RPC_URL)
    CHAIN_ID := 11155111
else ifeq ($(NETWORK),mainnet)
    RPC_URL := $(MAINNET_RPC_URL)
    CHAIN_ID := 1
else
    $(error Unsupported network: $(NETWORK). Use 'sepolia' or 'mainnet')
endif

.PHONY: help install build test clean deploy-factory deploy-basic deploy-permissioned deploy-all verify

help: ## Show this help message
	@echo "$(CYAN)MultiHookAdapter Deployment Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup Commands:$(NC)"
	@echo "  make install           Install dependencies"
	@echo "  make build             Build all contracts"
	@echo "  make test              Run all tests"
	@echo "  make clean             Clean build artifacts"
	@echo ""
	@echo "$(YELLOW)Deployment Commands:$(NC)"
	@echo "  make deploy-factory    Deploy factory system"
	@echo "  make deploy-basic      Deploy basic adapter example"
	@echo "  make deploy-permissioned Deploy permissioned adapter example"
	@echo "  make deploy-all        Deploy everything (factory + examples)"
	@echo "  make verify            Verify deployment integrity"
	@echo ""
	@echo "$(YELLOW)Network Configuration:$(NC)"
	@echo "  NETWORK=sepolia (default) or mainnet"
	@echo "  Example: make deploy-factory NETWORK=mainnet"
	@echo ""
	@echo "$(YELLOW)Current Configuration:$(NC)"
	@echo "  Network: $(NETWORK)"
	@echo "  Chain ID: $(CHAIN_ID)"
	@echo "  RPC URL: $(RPC_URL)"

install: ## Install Foundry dependencies
	@echo "$(CYAN)Installing dependencies...$(NC)"
	forge install
	@echo "$(GREEN)Dependencies installed ✓$(NC)"

build: ## Build all contracts
	@echo "$(CYAN)Building contracts...$(NC)"
	forge build
	@echo "$(GREEN)Build complete ✓$(NC)"

test: ## Run all tests
	@echo "$(CYAN)Running tests...$(NC)"
	forge test --summary
	@echo "$(GREEN)Tests complete ✓$(NC)"

clean: ## Clean build artifacts
	@echo "$(CYAN)Cleaning build artifacts...$(NC)"
	forge clean
	rm -f deployments-*.env
	rm -f basic-adapter-*.env
	rm -f permissioned-adapter-*.env
	rm -f advanced-deployment-*.env
	@echo "$(GREEN)Clean complete ✓$(NC)"

sizes: ## Check contract sizes
	@echo "$(CYAN)Checking contract sizes...$(NC)"
	forge build --sizes | grep -E "(Factory|Adapter)"

check-env: ## Check environment configuration
	@echo "$(CYAN)Checking environment configuration...$(NC)"
	@if [ -z "$(PRIVATE_KEY)" ]; then \
		echo "$(RED)Error: PRIVATE_KEY not set$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(RPC_URL)" ]; then \
		echo "$(RED)Error: RPC_URL not set for network $(NETWORK)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Environment configuration valid ✓$(NC)"

deploy-factory: check-env build ## Deploy factory system
	@echo "$(CYAN)Deploying factory system to $(NETWORK)...$(NC)"
	forge script scripts/DeployFactory.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--legacy
	@echo "$(GREEN)Factory deployment complete ✓$(NC)"

deploy-basic: check-env ## Deploy basic adapter example
	@echo "$(CYAN)Deploying basic adapter to $(NETWORK)...$(NC)"
	@if [ ! -f "deployments-$(CHAIN_ID).env" ]; then \
		echo "$(RED)Error: Factory not deployed. Run 'make deploy-factory' first$(NC)"; \
		exit 1; \
	fi
	forge script scripts/DeployBasicAdapter.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--legacy
	@echo "$(GREEN)Basic adapter deployment complete ✓$(NC)"

deploy-permissioned: check-env ## Deploy permissioned adapter example
	@echo "$(CYAN)Deploying permissioned adapter to $(NETWORK)...$(NC)"
	@if [ ! -f "deployments-$(CHAIN_ID).env" ]; then \
		echo "$(RED)Error: Factory not deployed. Run 'make deploy-factory' first$(NC)"; \
		exit 1; \
	fi
	forge script scripts/DeployPermissionedAdapter.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--legacy
	@echo "$(GREEN)Permissioned adapter deployment complete ✓$(NC)"

deploy-examples: check-env ## Deploy example adapters using helper
	@echo "$(CYAN)Deploying example adapters with helper to $(NETWORK)...$(NC)"
	@if [ ! -f "deployments-$(CHAIN_ID).env" ]; then \
		echo "$(RED)Error: Factory not deployed. Run 'make deploy-factory' first$(NC)"; \
		exit 1; \
	fi
	forge script scripts/DeployWithHelper.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--legacy
	@echo "$(GREEN)Example adapter deployment complete ✓$(NC)"

deploy-all: deploy-factory deploy-basic deploy-permissioned ## Deploy factory and example adapters
	@echo "$(GREEN)Complete deployment finished ✓$(NC)"

verify: ## Verify deployment integrity
	@echo "$(CYAN)Verifying deployment...$(NC)"
	@if [ ! -f "deployments-$(CHAIN_ID).env" ]; then \
		echo "$(RED)Error: No deployment found for network $(NETWORK)$(NC)"; \
		exit 1; \
	fi
	forge script scripts/VerifyDeployment.s.sol \
		--rpc-url $(RPC_URL)
	@echo "$(GREEN)Verification complete ✓$(NC)"

verify-etherscan: ## Verify contracts on Etherscan
	@echo "$(CYAN)Verifying contracts on Etherscan...$(NC)"
	@if [ -z "$(ETHERSCAN_API_KEY)" ]; then \
		echo "$(RED)Error: ETHERSCAN_API_KEY not set$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "deployments-$(CHAIN_ID).env" ]; then \
		echo "$(RED)Error: No deployment found for network $(NETWORK)$(NC)"; \
		exit 1; \
	fi
	@source deployments-$(CHAIN_ID).env && \
	echo "Verifying BasicAdapterFactory..." && \
	forge verify-contract $$BASIC_ADAPTER_FACTORY \
		src/factory/BasicAdapterFactory.sol:BasicAdapterFactory \
		--chain $(NETWORK) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) || echo "$(YELLOW)BasicAdapterFactory verification failed$(NC)" && \
	echo "Verifying PermissionedAdapterFactory..." && \
	forge verify-contract $$PERMISSIONED_ADAPTER_FACTORY \
		src/factory/PermissionedAdapterFactory.sol:PermissionedAdapterFactory \
		--chain $(NETWORK) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) || echo "$(YELLOW)PermissionedAdapterFactory verification failed$(NC)" && \
	echo "Verifying MultiHookAdapterFactory..." && \
	forge verify-contract $$MULTI_HOOK_ADAPTER_FACTORY \
		src/factory/MultiHookAdapterFactory.sol:MultiHookAdapterFactory \
		--chain $(NETWORK) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--constructor-args $$(cast abi-encode "constructor(address,address)" $$BASIC_ADAPTER_FACTORY $$PERMISSIONED_ADAPTER_FACTORY) || echo "$(YELLOW)MultiHookAdapterFactory verification failed$(NC)" && \
	echo "Verifying AdapterDeploymentHelper..." && \
	forge verify-contract $$ADAPTER_DEPLOYMENT_HELPER \
		src/factory/AdapterDeploymentHelper.sol:AdapterDeploymentHelper \
		--chain $(NETWORK) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--constructor-args $$(cast abi-encode "constructor(address)" $$MULTI_HOOK_ADAPTER_FACTORY) || echo "$(YELLOW)AdapterDeploymentHelper verification failed$(NC)"
	@echo "$(GREEN)Etherscan verification complete ✓$(NC)"

status: ## Show deployment status
	@echo "$(CYAN)Deployment Status for $(NETWORK):$(NC)"
	@echo ""
	@if [ -f "deployments-$(CHAIN_ID).env" ]; then \
		echo "$(GREEN)Factory System:$(NC)"; \
		cat deployments-$(CHAIN_ID).env | sed 's/^/  /'; \
		echo ""; \
	else \
		echo "$(YELLOW)Factory system not deployed$(NC)"; \
	fi
	@if [ -f "basic-adapter-$(CHAIN_ID).env" ]; then \
		echo "$(GREEN)Basic Adapter:$(NC)"; \
		cat basic-adapter-$(CHAIN_ID).env | sed 's/^/  /'; \
		echo ""; \
	else \
		echo "$(YELLOW)Basic adapter not deployed$(NC)"; \
	fi
	@if [ -f "permissioned-adapter-$(CHAIN_ID).env" ]; then \
		echo "$(GREEN)Permissioned Adapter:$(NC)"; \
		cat permissioned-adapter-$(CHAIN_ID).env | sed 's/^/  /'; \
		echo ""; \
	else \
		echo "$(YELLOW)Permissioned adapter not deployed$(NC)"; \
	fi

# Development shortcuts
dev-setup: install build test ## Complete development setup
	@echo "$(GREEN)Development setup complete ✓$(NC)"

dev-deploy: deploy-factory verify ## Quick development deployment
	@echo "$(GREEN)Development deployment complete ✓$(NC)"

# Emergency commands
emergency-clean: ## Clean everything (use with caution)
	@echo "$(RED)Emergency clean - removing all artifacts...$(NC)"
	@read -p "Are you sure? This will remove all deployment files [y/N]: " confirm && [ "$$confirm" = "y" ]
	forge clean
	rm -f *.env
	rm -f deployments-*.env
	rm -f basic-adapter-*.env
	rm -f permissioned-adapter-*.env
	rm -f advanced-deployment-*.env
	@echo "$(GREEN)Emergency clean complete$(NC)"