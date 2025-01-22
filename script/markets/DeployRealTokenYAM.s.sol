// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RealTokenYamUpgradeableV3} from "../../src/markets/RealTokenYamUpgradeableV3.sol";

contract DeployRealTokenYAM is Script {
    struct Initializer {
        address admin;
        address moderator;
    }

    function run(address owner) external returns (address) {
        Initializer memory initializer = Initializer(owner, owner);
        console.log("_DeployRealTokenYAM");
        (address proxy, address implementation) = deploy(initializer);
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);

        return proxy;
    }

    function deploy(Initializer memory initializer) private returns (address proxy, address implementation) {
        implementation = deployRealTokenYamUpgradeableV3();
        proxy = deployProxyByOwner(initializer, implementation);

        return (proxy, implementation);
    }

    function deployRealTokenYamUpgradeableV3() private returns (address) {
        vm.startBroadcast();
        RealTokenYamUpgradeableV3 implementation = new RealTokenYamUpgradeableV3();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(Initializer memory initializer, address implementation) private returns (address) {
        bytes memory data = abi.encodeWithSelector(
            RealTokenYamUpgradeableV3.initialize.selector, initializer.admin, initializer.moderator
        ); // set proxy admin & moderator
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
