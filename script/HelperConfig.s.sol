// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {DeployCleanSatMining} from "../script/market/DeployCleanSatMining.s.sol";
import {DeployUSDCToken} from "../script/tokens/DeployUSDCToken.s.sol";
import {DeployCSMToken} from "../script/tokens/DeployCSMToken.s.sol";
import {CleanSatMining, ICleanSatMining} from "../src/market/CleanSatMining.sol";
import {USDCMock} from "../test/mocks/USDCMock.sol";
import {CSMMock} from "../test/mocks/CSMMock.sol";

contract HelperConfig is Script {
    error HelperConfig__ConfigIsNotActive();

    struct NetworkConfig {
        address admin;
        address moderator;
        address asset;
        address market;
        address[] csmTokens;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 100) {
            activeNetworkConfig = getGnosisConfig();
        } else {
            // 31337 => Local chain (Anvil id)
            activeNetworkConfig = getLocalConfig();
        }
    }

    modifier onlyActiveConfig() {
        if (activeNetworkConfig.asset == address(0)) {
            revert HelperConfig__ConfigIsNotActive();
        }
        _;
    }

    function createOfferForAlphaToken(uint256 _offerPrice, uint256 _offerAmount) public onlyActiveConfig {
        createPublicOffer(activeNetworkConfig.csmTokens[0], activeNetworkConfig.asset, _offerPrice, _offerAmount);
    }

    function createPublicOffer(address _offerToken, address _buyerToken, uint256 _offerPrice, uint256 _offerAmount)
        private
        onlyActiveConfig
    {
        vm.startBroadcast(activeNetworkConfig.admin);
        CSMMock(_offerToken).approve(activeNetworkConfig.market, _offerAmount);
        CleanSatMining(activeNetworkConfig.market).createOffer(
            _offerToken, _buyerToken, address(0), _offerPrice, _offerAmount
        );
        vm.stopBroadcast();
    }

    function getcsmTokens() public view onlyActiveConfig returns (address[] memory) {
        address[] memory csmTokens = new address[](activeNetworkConfig.csmTokens.length);

        for (uint256 i = 0; i < activeNetworkConfig.csmTokens.length; i++) {
            csmTokens[i] = activeNetworkConfig.csmTokens[i];
        }

        return csmTokens;
    }

    function getGnosisConfig() public view returns (NetworkConfig memory) {
        if (activeNetworkConfig.asset != address(0)) {
            return activeNetworkConfig;
        }

        address[] memory csmTokens = new address[](2);
        csmTokens[0] = address(0);
        csmTokens[1] = address(0);

        return NetworkConfig({
            admin: vm.envAddress("ADMIN_PUBLIC_KEY"),
            moderator: vm.envAddress("MODERATOR_PUBLIC_KEY"),
            asset: 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83,
            market: 0x7ac028f8Fe6e7705292dC13E46a609DD95fc84ba,
            csmTokens: csmTokens
        });
    }

    function getLocalConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.asset != address(0)) {
            return activeNetworkConfig;
        }

        return _createLocalConfig();
    }

    function _createLocalConfig() private returns (NetworkConfig memory) {
        address admin = vm.envAddress("ADMIN_PUBLIC_KEY");
        address moderator = vm.envAddress("MODERATOR_PUBLIC_KEY");

        // Setup Asset
        address asset = new DeployUSDCToken().run();
        vm.startBroadcast();
        USDCMock(asset).mint(admin, 1000000 * uint256(10) ** USDCMock(asset).decimals()); // 1,000,000.000_000
        vm.stopBroadcast();
        vm.startBroadcast(admin);
        USDCMock(asset).transfer(moderator, 10000 * uint256(10) ** USDCMock(asset).decimals()); // 10,000.000_000
        vm.stopBroadcast();

        // Setup CSM TOKENS
        DeployCSMToken csmDeployer = new DeployCSMToken();
        address csmAlpha = csmDeployer.run("CleanSatMining ALPHA", "CSM-ALPHA");
        address csmDelta = csmDeployer.run("CleanSatMining DELTA", "CSM-DELTA");
        address[] memory csmTokens = new address[](2);
        csmTokens[0] = csmAlpha;
        csmTokens[1] = csmDelta;
        vm.startBroadcast();
        CSMMock(csmAlpha).mint(admin, 141723598152480); // CSM-ALPHA => 141,723.59815248 tokens
        CSMMock(csmDelta).mint(admin, 219566245519713); // CSM-DELTA => 219,566.245519713 tokens
        vm.stopBroadcast();

        // Set up CSM Market
        address market = new DeployCleanSatMining().run(admin);

        // NETWORK CONFIG
        NetworkConfig memory config =
            NetworkConfig({admin: admin, moderator: moderator, asset: asset, market: market, csmTokens: csmTokens});

        // Set up Whitelist for CSM Market
        address[] memory tokens = new address[](3);
        tokens[0] = asset;
        tokens[1] = csmAlpha;
        tokens[2] = csmDelta;
        ICleanSatMining.TokenType[] memory types = new ICleanSatMining.TokenType[](3);
        types[0] = ICleanSatMining.TokenType.ERC20WITHPERMIT;
        types[1] = ICleanSatMining.TokenType.CLEANSATMINING;
        types[2] = ICleanSatMining.TokenType.CLEANSATMINING;
        vm.startBroadcast(admin);
        CleanSatMining(market).toggleWhitelistWithType(tokens, types);
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
