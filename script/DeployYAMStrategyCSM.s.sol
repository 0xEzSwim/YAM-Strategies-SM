// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {YAMStrategyCSM} from "../src/YAMStrategyCSM.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployYAMStrategyCSM is Script {
    struct Initializer {
        address admin;
        address moderator;
        string name;
        address asset;
        address csmMarket;
        address[] csmTokens;
    }

    function run(string memory strategyName) external returns (address) {
        HelperConfig config = new HelperConfig();
        (address admin, address moderator, address asset, address csmMarket) = config.activeNetworkConfig();
        address[] memory csmTokens = config.getcsmTokens();
        Initializer memory initializer = Initializer(admin, moderator, strategyName, asset, csmMarket, csmTokens);
        console.log("_DeployYAMStrategyCSM_");
        (address proxy, address implementation) = deploy(initializer);
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);
        console.log("\t=>Token Name:", YAMStrategyCSM(proxy).name());
        console.log("\t=>Token Symbol:", YAMStrategyCSM(proxy).symbol());

        return proxy;
    }

    function deploy(Initializer memory _initializer) private returns (address proxy, address implementation) {
        implementation = deployStrategy();
        proxy = deployProxyByOwner(_initializer, implementation);

        return (proxy, implementation);
    }

    function deployStrategy() private returns (address) {
        vm.startBroadcast();
        YAMStrategyCSM implementation = new YAMStrategyCSM();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(Initializer memory _initializer, address _implementation) private returns (address) {
        bytes memory data = abi.encodeWithSelector(
            YAMStrategyCSM.initialize.selector,
            _initializer.admin,
            _initializer.moderator,
            _initializer.name,
            _initializer.asset,
            _initializer.csmMarket,
            _initializer.csmTokens
        ); // set proxy admin, moderator, vaul asset, market & CSM tokens
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(address(_implementation), data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
