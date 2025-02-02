// SPX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RealTokenYamUpgradeableV3} from "../../src/markets/RealTokenYamUpgradeableV3.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract DeployRealTokenYAM is Script {
    function run(address owner) external returns (address) {
        console.log("_DeployRealTokenYAM");
        (address proxy, address implementation) = _deploy(owner);
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);

        return proxy;
    }

    function _deploy(address owner) private returns (address proxy, address implementation) {
        implementation = deployRealTokenYamUpgradeableV3();
        proxy = deployProxyByOwner(owner);

        return (proxy, implementation);
    }

    function deployRealTokenYamUpgradeableV3() public returns (address) {
        vm.startBroadcast();
        RealTokenYamUpgradeableV3 implementation = new RealTokenYamUpgradeableV3();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(address owner) public returns (address) {
        address implementation = DevOpsTools.get_most_recent_deployment("RealTokenYamUpgradeableV3", block.chainid);
        bytes memory data = abi.encodeWithSelector(RealTokenYamUpgradeableV3.initialize.selector, owner, owner); // set proxy admin & moderator
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
