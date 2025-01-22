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

# BOX_NETWORK_ARGS := --sig "run(address)" $(LOCAL_PUBLIC_KEY) --rpc-url $(LOCAL_RPC_URL) --private-key $(LOCAL_DEPLOYER_PRIVATE_KEY) --broadcast

# ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
# 	BOX_NETWORK_ARGS := --sig "run(address)" $(SEPOLIA_PUBLIC_KEY) --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvvv
# endif

# deploy-box:
# 	@forge script script/box/DeployBox.s.sol:DeployBox $(BOX_NETWORK_ARGS)

# upgrade-box:
# 	@forge script script/box/UpgradeBox.s.sol:UpgradeBox $(BOX_NETWORK_ARGS)

# get-local-box-owner:
# 	@cast call $(PROXY_CONTRACT_ADDRESS) "owner()(address)" --rpc-url $(LOCAL_RPC_URL)

# get-local-box-version:
# 	@cast call $(PROXY_CONTRACT_ADDRESS) "getVersion()(uint64)" --rpc-url $(LOCAL_RPC_URL)

# get-sepolia-box-owner:
# 	@cast call $(PROXY_CONTRACT_ADDRESS) "owner()(address)" --rpc-url $(SEPOLIA_RPC_URL)

# get-sepolia-box-version:
# 	@cast call $(PROXY_CONTRACT_ADDRESS) "getVersion()(uint64)" --rpc-url $(SEPOLIA_RPC_URL)

dev: fund-accounts
	@forge script script/tokens/DeployUSDCToken.s.sol:DeployUSDCToken --sig "run()" --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)
	@forge script script/strategies/cleanSatMining/DeployYAMStrategyCSM.s.sol:DeployYAMStrategyCSM --sig "run(string)" "Undervalued" --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)
	@forge script script/strategies/realt/DeployYAMStrategyRealt.s.sol:DeployYAMStrategyRealt --sig "run(string)" "Undervalued RWA" --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)

fund-accounts:
	@cast send --value 100ether --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 $(ADMIN_PUBLIC_KEY)
	@cast send --value 100ether --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 $(MODERATOR_PUBLIC_KEY)

create-local-offer:
	@forge script script/markets/ActionCleanSatMining.s.sol:ActionCleanSatMining --sig "createPublicSellingOfferForAlphaToken(uint256,uint256)" 16500000 100000000000 --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)

update-local-offer:
	@forge script script/markets/ActionCleanSatMining.s.sol:ActionCleanSatMining --sig "updatePublicSellingOfferForDeltaToken(uint256,uint256)" 7900000 200000000000 --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)

toggle-local-strategy-status:
	@forge script script/strategies/cleanSatMining/ActionYAMStrategyCSM.s.sol:ActionYAMStrategyCSM --sig "toggleStrategyStatus()" --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)

get-local-strategy-tvl:
	@forge script script/strategies/cleanSatMining/ActionYAMStrategyCSM.s.sol:ActionYAMStrategyCSM --sig "getTvl()" --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)

get-local-asset-in-strategy:
	@forge script script/strategies/cleanSatMining/ActionYAMStrategyCSM.s.sol:ActionYAMStrategyCSM --sig "getAssetBalance()" --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)

get-local-alpha-in-strategy:
	@forge script script/strategies/cleanSatMining/ActionYAMStrategyCSM.s.sol:ActionYAMStrategyCSM --sig "getAlphaBalance()" --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)

get-local-delta-in-strategy:
	@forge script script/strategies/cleanSatMining/ActionYAMStrategyCSM.s.sol:ActionYAMStrategyCSM --sig "getDeltaBalance()" --rpc-url $(LOCAL_RPC_URL) --broadcast --account $(ADMIN_ACCOUNT_NAME) --password $(ADMIN_ACCOUNT_PASSWORD) --sender $(ADMIN_PUBLIC_KEY)
