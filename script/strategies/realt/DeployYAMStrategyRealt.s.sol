// SPX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {YAMStrategyRealt} from "../../../src/strategies/YAMStrategyRealt.sol";
import {HelperConfigYAMStrategyRealt} from "./HelperConfigYAMStrategyRealt.s.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract DeployYAMStrategyRealt is Script {
    function run(string memory strategyName) external returns (address) {
        console.log("_DeployYAMStrategyRealt_");
        (address proxy, address implementation) = _deploy(strategyName);
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);
        console.log("\t=>Token Name:", YAMStrategyRealt(proxy).name());
        console.log("\t=>Token Symbol:", YAMStrategyRealt(proxy).symbol());

        return proxy;
    }

    function _deploy(string memory strategyName) private returns (address proxy, address implementation) {
        implementation = deployStrategy();
        proxy = deployProxyByOwner(strategyName);

        return (proxy, implementation);
    }

    function deployStrategy() public returns (address) {
        vm.startBroadcast();
        YAMStrategyRealt implementation = new YAMStrategyRealt();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(string memory strategyName) public returns (address) {
        address implementation = DevOpsTools.get_most_recent_deployment("YAMStrategyRealt", block.chainid);
        HelperConfigYAMStrategyRealt config = new HelperConfigYAMStrategyRealt();
        (address admin, address moderator, address asset, address market) = config.activeNetworkConfig();
        address[] memory tokens = config.getTokens();

        bytes memory data = abi.encodeWithSelector(
            YAMStrategyRealt.initialize.selector, admin, moderator, strategyName, asset, market, tokens
        ); // set proxy admin, moderator, name ,vaul asset, market & tokens
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
