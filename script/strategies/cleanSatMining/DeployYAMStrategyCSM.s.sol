// SPX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {YAMStrategyCSM} from "../../../src/strategies/YAMStrategyCSM.sol";
import {HelperConfigYAMStrategyCSM} from "./HelperConfigYAMStrategyCSM.s.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract DeployYAMStrategyCSM is Script {
    function run(string memory strategyName) external returns (address) {
        (address proxy, address implementation) = _deploy(strategyName);
        console.log("_DeployYAMStrategyCSM_");
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);
        console.log("\t=>Token Name:", YAMStrategyCSM(proxy).name());
        console.log("\t=>Token Symbol:", YAMStrategyCSM(proxy).symbol());

        return proxy;
    }

    function _deploy(string memory strategyName) private returns (address proxy, address implementation) {
        implementation = deployStrategy();
        proxy = _deployProxyByOwner(strategyName, implementation);

        return (proxy, implementation);
    }

    function deployStrategy() public returns (address) {
        vm.startBroadcast();
        YAMStrategyCSM implementation = new YAMStrategyCSM();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(string memory strategyName, address implementation) public returns (address) {
        address implementation = DevOpsTools.get_most_recent_deployment("YAMStrategyCSM", block.chainid);
        return _deployProxyByOwner(strategyName, implementation);
    }

    function _deployProxyByOwner(string memory strategyName, address implementation) private returns (address) {
        HelperConfigYAMStrategyCSM config = new HelperConfigYAMStrategyCSM();
        (address admin, address moderator, address asset, address market) = config.activeNetworkConfig();
        address[] memory tokens = config.getTokens();

        bytes memory data = abi.encodeWithSelector(
            YAMStrategyCSM.initialize.selector, admin, moderator, strategyName, asset, market, tokens
        ); // set proxy admin, moderator, vaul asset, market & CSM tokens
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vm.stopBroadcast();

        return address(proxy);
    }
}
