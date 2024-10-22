// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CSMStrategy} from "../src/CSMStrategy.sol";

contract DeployCSMStrategy is Script {
    struct Initializer {
        address admin;
        address moderator;
        address asset;
        address csmMarket;
        address[] csmTokens;
    }

    function run(address _admin, address _moderator, address _asset, address _csmMarket, address[] memory _csmTokens)
        external
        returns (address)
    {
        Initializer memory initializer = Initializer(_admin, _moderator, _asset, _csmMarket, _csmTokens);
        (address proxy, address implementation) = deploy(initializer);
        console.log("_DeployCSMStrategy_");
        console.log("proxy address:", proxy);
        console.log("implementation address:", implementation);

        return proxy;
    }

    function deploy(Initializer memory _initializer) private returns (address proxy, address implementation) {
        implementation = deployStrategy();
        proxy = deployProxyByOwner(_initializer, implementation);

        return (proxy, implementation);
    }

    function deployStrategy() private returns (address) {
        vm.startBroadcast();
        CSMStrategy implementation = new CSMStrategy();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(Initializer memory _initializer, address _implementation) private returns (address) {
        bytes memory data = abi.encodeWithSelector(
            CSMStrategy.initialize.selector,
            _initializer.admin,
            _initializer.moderator,
            _initializer.asset,
            _initializer.csmMarket,
            _initializer.csmTokens
        ); // set proxy owner, vaul asset, market & CSM tokens
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(address(_implementation), data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
