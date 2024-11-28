// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {YAMStrategyCSM} from "../src/YAMStrategyCSM.sol";
import {CleanSatMining} from "../src/market/CleanSatMining.sol";
import {USDCMock} from "../test/mocks/USDCMock.sol";
import {CSMMock} from "../test/mocks/CSMMock.sol";

contract ActionYAMStrategyCSM is Script {
    address public ADMIN = vm.envAddress("ADMIN_PUBLIC_KEY");
    address constant CSM_STRATEGY = 0x7860fa929e453A38115699dE11739C2ad42D09c5;
    address constant CSM_MARKET = 0xC588428fC4AfBa21B94ab158fc63E0D4d179D4CB;
    address constant USDC_TOKEN = 0x1197161d6e86A0F881B95E02B8DA07E56b6a751A;
    address constant CSM_ALPHA_TOKEN = 0x5A768Da857aD9b112631f88892CdE57E09AA8A6A;
    address constant CSM_DELTA_TOKEN = 0xC731074a0c0f078C6474049AF4d5560fa70D7F77;

    function toggleStrategyStatus() public {
        vm.startBroadcast(ADMIN);
        if (!YAMStrategyCSM(CSM_STRATEGY).paused()) {
            YAMStrategyCSM(CSM_STRATEGY).pause();
        } else {
            YAMStrategyCSM(CSM_STRATEGY).unpause();
        }
        vm.stopBroadcast();
    }

    function getAssetBalance() public view {
        console.log(USDCMock(USDC_TOKEN).balanceOf(CSM_STRATEGY));
    }

    function getAlphaBalance() public view {
        console.log(CSMMock(CSM_ALPHA_TOKEN).balanceOf(CSM_STRATEGY));
    }

    function getDeltaBalance() public view {
        console.log(CSMMock(CSM_DELTA_TOKEN).balanceOf(CSM_STRATEGY));
    }
}
