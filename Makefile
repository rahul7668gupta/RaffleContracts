-include .env

fund-sub-sepolia:;
	forge script script/Interactions.s.sol:FundSubscription --broadcast --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT_WALLET)

fund-sub-anvil:;
	forge script script/Interactions.s.sol:FundSubscription --broadcast

test-fork-sepolia:;
	forge test --rpc-url $(SEPOLIA_RPC_URL)

install:;
	forge install foundry-rs/forge-std@v1.9.1 --no-commit && forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install transmissions11/solmate@v6 --no-commit

deploy-sepolia:;
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT_WALLET) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)