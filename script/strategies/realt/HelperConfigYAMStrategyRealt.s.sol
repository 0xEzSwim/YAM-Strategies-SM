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
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

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

    function _createSepoliaConfig() internal view override returns (NetworkConfig memory) {
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

    function _createLocalConfig() internal view override returns (NetworkConfig memory) {
        address admin = vm.envAddress("ADMIN_PUBLIC_KEY");
        address moderator = vm.envAddress("MODERATOR_PUBLIC_KEY");

        // Get Underlying Asset
        address asset = DevOpsTools.get_most_recent_deployment("USDCMock", block.chainid);

        // Get TOKENS
        address rwaToken = DevOpsTools.get_most_recent_deployment("RealTokenMock", block.chainid);
        address[] memory tokens = new address[](1);
        tokens[0] = rwaToken;

        // Get Market
        address marketImplementation =
            DevOpsTools.get_most_recent_deployment("RealTokenYamUpgradeableV3", block.chainid);
        string memory marketString = Strings.toChecksumHexString(marketImplementation);
        address market = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", marketString, block.chainid);

        return NetworkConfig({admin: admin, moderator: moderator, asset: asset, market: market, tokens: tokens});
    }
}
