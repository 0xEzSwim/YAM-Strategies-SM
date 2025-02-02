// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfigYAMStrategy} from "../HelperConfigYAMStrategy.s.sol";
import {DeployRealTokenYAM} from "../../../script/markets/DeployRealTokenYAM.s.sol";
import {DeployUSDCToken} from "../../../script/tokens/DeployUSDCToken.s.sol";
import {DeployRealToken} from "../../../script/tokens/DeployRealToken.s.sol";
import {
    RealTokenYamUpgradeableV3, IRealTokenYamUpgradeableV3
} from "../../../src/markets/RealTokenYamUpgradeableV3.sol";
import {USDCMock} from "../../../test/mocks/USDCMock.sol";
import {RealTokenMock} from "../../../test/mocks/RealTokenMock.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract HelperConfigYAMStrategyRealt is HelperConfigYAMStrategy, Script {
    constructor() {
        __HelperConfigYAMStrategy_init();
    }

    function _createGnosisConfig() internal view override returns (NetworkConfig memory) {
        address[] memory tokens = new address[](1);
        tokens[0] = 0x0675e8F4A52eA6c845CB6427Af03616a2af42170; // RWA-HOLDINGS

        return NetworkConfig({
            admin: vm.envAddress("ADMIN_PUBLIC_KEY"),
            moderator: vm.envAddress("MODERATOR_PUBLIC_KEY"),
            asset: 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83, // USDC on Xdai
            market: 0xC759AA7f9dd9720A1502c104DaE4F9852bb17C14, // YAM RealT proxy
            tokens: tokens
        });
    }

    function _createSepoliaConfigOnce(NetworkConfig memory config) private returns (NetworkConfig memory) {
        // Set up Whitelist for CSM Market
        address[] memory whitelistedTokens = new address[](2);
        whitelistedTokens[0] = config.asset;
        whitelistedTokens[1] = config.tokens[0];
        IRealTokenYamUpgradeableV3.TokenType[] memory tokenTypes = new IRealTokenYamUpgradeableV3.TokenType[](2);
        tokenTypes[0] = IRealTokenYamUpgradeableV3.TokenType.ERC20WITHPERMIT;
        tokenTypes[1] = IRealTokenYamUpgradeableV3.TokenType.REALTOKEN;
        vm.startBroadcast(config.admin);
        RealTokenYamUpgradeableV3(config.market).toggleWhitelistWithType(whitelistedTokens, tokenTypes);
        vm.stopBroadcast();

        // Set up Market offers
        vm.startBroadcast(config.admin);
        // approve & create offer to sell 100 CSM-ALPHA for 14.05 USDC
        uint256 offerPrice = 5000 * uint256(10) ** (USDCMock(config.asset).decimals() - 2);
        uint256 offerAmount = 100 * uint256(10) ** RealTokenMock(config.tokens[0]).decimals();
        RealTokenMock(config.tokens[0]).approve(config.market, offerAmount);
        RealTokenYamUpgradeableV3(config.market).createOffer(
            config.tokens[0], config.asset, address(0), offerPrice, offerAmount
        );
        vm.stopBroadcast();

        uint256 offerCount = RealTokenYamUpgradeableV3(config.market).getOfferCount();
        console.log("# of offers on market:", offerCount);
        for (uint256 offerId = 0; offerId < offerCount; offerId++) {
            (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
                RealTokenYamUpgradeableV3(config.market).showOffer(offerId);
            console.log("__ offer #", offerId, "__");
            console.log("market offer's seller:", seller);
            console.log("market offer is private:", buyer == address(0));
            console.log("market offer tokens to send:", offerToken, amount);
            console.log("market offer tokens to receive:", buyerToken, price);
        }

        return config;
    }

    function _createSepoliaConfig() internal override returns (NetworkConfig memory) {
        address[] memory tokens = new address[](1);
        tokens[0] = 0x321736061AC6e0372DD729Fd83629D8F7F5DEA94; // RWA-HOLDINGS.M

        return NetworkConfig({
            admin: vm.envAddress("ADMIN_PUBLIC_KEY"),
            moderator: vm.envAddress("MODERATOR_PUBLIC_KEY"),
            asset: 0x1197161d6e86A0F881B95E02B8DA07E56b6a751A, // USDC.M
            market: 0x7860fa929e453A38115699dE11739C2ad42D09c5, // YAM RealT proxy
            tokens: tokens
        });
    }

    function _createLocalConfig() internal override returns (NetworkConfig memory) {
        address admin = vm.envAddress("ADMIN_PUBLIC_KEY");
        address moderator = vm.envAddress("MODERATOR_PUBLIC_KEY");

        // Get Underlying Asset
        address asset = DevOpsTools.get_most_recent_deployment("USDCMock", block.chainid);

        // Setup CSM TOKENS
        DeployRealToken realTokenDeployer = new DeployRealToken();
        address rwaToken = realTokenDeployer.run(
            "RealToken RWA Holdings SA, Neuchatel, NE, Suisse Mock", "REALTOKEN-CH-S-RWA-HOLDINGS-SA-NEUCHATEL-NE.M"
        );
        address[] memory tokens = new address[](1);
        tokens[0] = rwaToken;
        vm.startBroadcast();
        RealTokenMock(rwaToken).mint(admin, 100000000000000); // RWA-HOLDINGS => 100,000.000000000 tokens
        vm.stopBroadcast();

        // Set up CSM Market
        address market = new DeployRealTokenYAM().run(admin);

        // NETWORK CONFIG
        NetworkConfig memory config =
            NetworkConfig({admin: admin, moderator: moderator, asset: asset, market: market, tokens: tokens});

        // Set up Whitelist for CSM Market
        address[] memory whitelistedTokens = new address[](2);
        whitelistedTokens[0] = asset;
        whitelistedTokens[1] = rwaToken;
        IRealTokenYamUpgradeableV3.TokenType[] memory tokenTypes = new IRealTokenYamUpgradeableV3.TokenType[](2);
        tokenTypes[0] = IRealTokenYamUpgradeableV3.TokenType.ERC20WITHPERMIT;
        tokenTypes[1] = IRealTokenYamUpgradeableV3.TokenType.REALTOKEN;
        vm.startBroadcast(admin);
        RealTokenYamUpgradeableV3(market).toggleWhitelistWithType(whitelistedTokens, tokenTypes);
        vm.stopBroadcast();

        // Set up Market offers
        vm.startBroadcast(admin);
        // approve & create offer to sell 100 CSM-ALPHA for 14.05 USDC
        uint256 offerPrice = 5000 * uint256(10) ** (USDCMock(asset).decimals() - 2);
        uint256 offerAmount = 100 * uint256(10) ** RealTokenMock(rwaToken).decimals();
        RealTokenMock(rwaToken).approve(market, offerAmount);
        RealTokenYamUpgradeableV3(market).createOffer(rwaToken, asset, address(0), offerPrice, offerAmount);
        vm.stopBroadcast();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1); // can't buy an offer from the same block number.

        uint256 offerCount = RealTokenYamUpgradeableV3(market).getOfferCount();
        console.log("# of offers on market:", offerCount);
        for (uint256 offerId = 0; offerId < offerCount; offerId++) {
            (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
                RealTokenYamUpgradeableV3(market).showOffer(offerId);
            console.log("__ offer #", offerId, "__");
            console.log("market offer's seller:", seller);
            console.log("market offer is private:", buyer == address(0));
            console.log("market offer tokens to send:", offerToken, amount);
            console.log("market offer tokens to receive:", buyerToken, price);
        }

        return config;
    }
}
