// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfigYAMStrategy} from "../HelperConfigYAMStrategy.s.sol";
import {DeployCleanSatMining} from "../../../script/markets/DeployCleanSatMining.s.sol";
import {DeployUSDCToken} from "../../../script/tokens/DeployUSDCToken.s.sol";
import {DeployCSMToken} from "../../../script/tokens/DeployCSMToken.s.sol";
import {CleanSatMining, ICleanSatMining} from "../../../src/markets/CleanSatMining.sol";
import {USDCMock} from "../../../test/mocks/USDCMock.sol";
import {CSMMock} from "../../../test/mocks/CSMMock.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract HelperConfigYAMStrategyCSM is HelperConfigYAMStrategy, Script {
    constructor() {
        __HelperConfigYAMStrategy_init();
    }

    function _createGnosisConfig() internal view override returns (NetworkConfig memory) {
        address[] memory tokens = new address[](3);
        tokens[0] = 0xf8419b6527A24007c2BD81bD1aA3b5a735C1F4c9; // CSM-ALPHA
        tokens[1] = 0x364D1aAF7a98e26A1F072e926032f154428481d1; // CSM-BETA
        tokens[2] = 0x203A5080450FFC3e038284082FBF5EBCdc9B053f; // CSM-OMEGA
        tokens[3] = 0x71C86CbB71846425De5f3a693e989F4BDd97E98d; // CSM-GAMMA
        tokens[4] = 0x20D2F2d4b839710562D25274A3e98Ea1F0392D24; // CSM-DELTA

        return NetworkConfig({
            admin: vm.envAddress("ADMIN_PUBLIC_KEY"),
            moderator: vm.envAddress("MODERATOR_PUBLIC_KEY"),
            asset: 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83,
            market: 0x7ac028f8Fe6e7705292dC13E46a609DD95fc84ba, // YAM CSM proxy
            tokens: tokens
        });
    }

    function _createSepoliaConfig() internal view override returns (NetworkConfig memory) {
        address[] memory tokens = new address[](3);
        tokens[0] = 0xf8419b6527A24007c2BD81bD1aA3b5a735C1F4c9; // CSM-ALPHA
        tokens[1] = 0x364D1aAF7a98e26A1F072e926032f154428481d1; // CSM-BETA
        tokens[2] = 0x203A5080450FFC3e038284082FBF5EBCdc9B053f; // CSM-OMEGA
        tokens[3] = 0x71C86CbB71846425De5f3a693e989F4BDd97E98d; // CSM-GAMMA
        tokens[4] = 0x20D2F2d4b839710562D25274A3e98Ea1F0392D24; // CSM-DELTA

        return NetworkConfig({
            admin: vm.envAddress("ADMIN_PUBLIC_KEY"),
            moderator: vm.envAddress("MODERATOR_PUBLIC_KEY"),
            asset: 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83,
            market: 0x7ac028f8Fe6e7705292dC13E46a609DD95fc84ba, // YAM CSM proxy
            tokens: tokens
        });
    }

    function _createLocalConfig() internal override returns (NetworkConfig memory) {
        address admin = vm.envAddress("ADMIN_PUBLIC_KEY");
        address moderator = vm.envAddress("MODERATOR_PUBLIC_KEY");

        // Get Underlying Asset
        address asset = DevOpsTools.get_most_recent_deployment("USDCMock", block.chainid);

        // Setup CSM TOKENS
        DeployCSMToken csmDeployer = new DeployCSMToken();
        address csmAlpha = csmDeployer.run("CleanSatMining ALPHA", "CSM-ALPHA");
        address csmDelta = csmDeployer.run("CleanSatMining DELTA", "CSM-DELTA");
        address[] memory tokens = new address[](2);
        tokens[0] = csmAlpha;
        tokens[1] = csmDelta;
        vm.startBroadcast();
        CSMMock(csmAlpha).mint(admin, 141723598152480); // CSM-ALPHA => 141,723.59815248 tokens
        CSMMock(csmDelta).mint(admin, 219566245519713); // CSM-DELTA => 219,566.245519713 tokens
        vm.stopBroadcast();

        // Set up CSM Market
        address market = new DeployCleanSatMining().run(admin);

        // NETWORK CONFIG
        NetworkConfig memory config =
            NetworkConfig({admin: admin, moderator: moderator, asset: asset, market: market, tokens: tokens});

        // Set up Whitelist for CSM Market
        address[] memory whitelistedTokens = new address[](3);
        whitelistedTokens[0] = asset;
        whitelistedTokens[1] = csmAlpha;
        whitelistedTokens[2] = csmDelta;
        ICleanSatMining.TokenType[] memory tokenTypes = new ICleanSatMining.TokenType[](3);
        tokenTypes[0] = ICleanSatMining.TokenType.ERC20WITHPERMIT;
        tokenTypes[1] = ICleanSatMining.TokenType.CLEANSATMINING;
        tokenTypes[2] = ICleanSatMining.TokenType.CLEANSATMINING;
        vm.startBroadcast(admin);
        CleanSatMining(market).toggleWhitelistWithType(whitelistedTokens, tokenTypes);
        vm.stopBroadcast();

        // Set up Market offers
        vm.startBroadcast(admin);
        // approve & create offer to sell 100 CSM-ALPHA for 14.05 USDC
        uint256 offerPrice = 1405 * uint256(10) ** (USDCMock(asset).decimals() - 2);
        uint256 offerAmount = 100 * uint256(10) ** CSMMock(csmAlpha).decimals();
        CSMMock(csmAlpha).approve(market, offerAmount);
        CleanSatMining(market).createOffer(csmAlpha, asset, address(0), offerPrice, offerAmount);
        // approve & create offer to sell 250 CSM-DELTA for 7.44 USDC
        offerPrice = 744 * uint256(10) ** (USDCMock(asset).decimals() - 2);
        offerAmount = 250 * uint256(10) ** CSMMock(csmDelta).decimals();
        CSMMock(csmDelta).approve(market, offerAmount);
        CleanSatMining(market).createOffer(csmDelta, asset, address(0), offerPrice, offerAmount);
        vm.stopBroadcast();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1); // can't buy an offer from the same block number.

        uint256 offerCount = CleanSatMining(market).getOfferCount();
        console.log("# of offers on market:", offerCount);
        for (uint256 offerId = 0; offerId < offerCount; offerId++) {
            (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
                CleanSatMining(market).showOffer(offerId);
            console.log("__ offer #", offerId, "__");
            console.log("market offer's seller:", seller);
            console.log("market offer is private:", buyer == address(0));
            console.log("market offer tokens to send:", offerToken, amount);
            console.log("market offer tokens to receive:", buyerToken, price);
        }

        return config;
    }
}
