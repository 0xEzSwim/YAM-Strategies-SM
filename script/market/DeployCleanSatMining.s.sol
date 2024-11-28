// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CleanSatMining} from "../../src/market/CleanSatMining.sol";

contract DeployCleanSatMining is Script {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    struct Initializer {
        address admin;
        address moderator;
    }

    function run(address owner) external returns (address) {
        Initializer memory initializer = Initializer(owner, owner);
        console.log("_DeployCleanSatMining_");
        (address proxy, address implementation) = deploy(initializer);
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);

        return proxy;
    }

    function deploy(Initializer memory initializer) private returns (address proxy, address implementation) {
        implementation = deployStrategy();
        proxy = deployProxyByOwner(initializer, implementation);

        return (proxy, implementation);
    }

    function deployStrategy() private returns (address) {
        vm.startBroadcast();
        CleanSatMining implementation = new CleanSatMining();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(Initializer memory initializer, address implementation) private returns (address) {
        bytes memory data =
            abi.encodeWithSelector(CleanSatMining.initialize.selector, initializer.admin, initializer.moderator); // set proxy admin & moderator
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
