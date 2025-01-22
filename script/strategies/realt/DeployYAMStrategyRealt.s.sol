// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {YAMStrategyRealt} from "../../../src/strategies/YAMStrategyRealt.sol";
import {HelperConfigYAMStrategyRealt} from "./HelperConfigYAMStrategyRealt.s.sol";

contract DeployYAMStrategyRealt is Script {
    struct Initializer {
        address admin;
        address moderator;
        string name;
        address asset;
        address market;
        address[] tokens;
    }

    function run(string memory strategyName) external returns (address) {
        HelperConfigYAMStrategyRealt config = new HelperConfigYAMStrategyRealt();
        (address admin, address moderator, address asset, address market) = config.activeNetworkConfig();
        address[] memory tokens = config.getTokens();
        Initializer memory initializer = Initializer(admin, moderator, strategyName, asset, market, tokens);
        console.log("_DeployYAMStrategyRealt_");
        (address proxy, address implementation) = deploy(initializer);
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);
        console.log("\t=>Token Name:", YAMStrategyRealt(proxy).name());
        console.log("\t=>Token Symbol:", YAMStrategyRealt(proxy).symbol());

        return proxy;
    }

    function deploy(Initializer memory initializer) private returns (address proxy, address implementation) {
        implementation = deployStrategy();
        proxy = deployProxyByOwner(initializer, implementation);

        return (proxy, implementation);
    }

    function deployStrategy() private returns (address) {
        vm.startBroadcast();
        YAMStrategyRealt implementation = new YAMStrategyRealt();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(Initializer memory initializer, address implementation) private returns (address) {
        bytes memory data = abi.encodeWithSelector(
            YAMStrategyRealt.initialize.selector,
            initializer.admin,
            initializer.moderator,
            initializer.name,
            initializer.asset,
            initializer.market,
            initializer.tokens
        ); // set proxy admin, moderator, vaul asset, market & tokens
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
