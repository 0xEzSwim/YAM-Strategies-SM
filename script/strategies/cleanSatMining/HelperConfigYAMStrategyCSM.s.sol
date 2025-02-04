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
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

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

    function _createLocalConfig() internal view override returns (NetworkConfig memory) {
        address admin = vm.envAddress("ADMIN_PUBLIC_KEY");
        address moderator = vm.envAddress("MODERATOR_PUBLIC_KEY");

        // Get Underlying Asset
        address asset = DevOpsTools.get_most_recent_deployment("USDCMock", block.chainid);

        // Get TOKENS
        address csmAlpha = DevOpsTools.get_most_recent_deployment("CSMMock", "CSM-ALPHA.M", block.chainid);
        address csmDelta = DevOpsTools.get_most_recent_deployment("CSMMock", "CSM-DELTA.M", block.chainid);
        address[] memory tokens = new address[](2);
        tokens[0] = csmAlpha;
        tokens[1] = csmDelta;

        // Get Market
        address marketImplementation = DevOpsTools.get_most_recent_deployment("CleanSatMining", block.chainid);
        string memory marketString = Strings.toChecksumHexString(marketImplementation);
        address market = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", marketString, block.chainid);

        return NetworkConfig({admin: admin, moderator: moderator, asset: asset, market: market, tokens: tokens});
    }
}
