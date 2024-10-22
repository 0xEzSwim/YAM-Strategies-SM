-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil scopefile

all: remove install build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit && forge install openzeppelin/openzeppelin-contracts-upgradeable@v4.8.3 --no-commit && forge install cyfrin/foundry-devops@0.0.11 --no-commit 

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --sig "run(address)" $(LOCAL_PUBLIC_KEY) --rpc-url $(LOCAL_RPC_URL) --private-key $(LOCAL_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --sig "run(address)" $(SEPOLIA_PUBLIC_KEY) --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvvv
endif

deploy-strat:
	@forge script script/Deploy.s.sol:Deploy $(NETWORK_ARGS)

upgrade-strat:
	@forge script script/Upgrade.s.sol:Upgrade $(NETWORK_ARGS)

get-local-owner:
	@cast call $(PROXY_CONTRACT_ADDRESS) "owner()(address)" --rpc-url $(LOCAL_RPC_URL)

get-local-version:
	@cast call $(PROXY_CONTRACT_ADDRESS) "getVersion()(uint64)" --rpc-url $(LOCAL_RPC_URL)

get-sepolia-owner:
	@cast call $(PROXY_CONTRACT_ADDRESS) "owner()(address)" --rpc-url $(SEPOLIA_RPC_URL)

get-sepolia-version:
	@cast call $(PROXY_CONTRACT_ADDRESS) "getVersion()(uint64)" --rpc-url $(SEPOLIA_RPC_URL)