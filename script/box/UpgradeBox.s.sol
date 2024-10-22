// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BoxV2} from "../../src/box/BoxV2.sol";
import {BoxV1} from "../../src/box/BoxV1.sol";

contract UpgradeBox is Script {
    function run(address _owner) external returns (address) {
        address proxy = vm.envAddress("PROXY_CONTRACT_ADDRESS");
        address implementation = upgrade(_owner, proxy);
        console.log("proxy address:", proxy);
        console.log("implementation address:", implementation);

        return proxy;
    }

    function upgrade(address _owner, address _proxy) private returns (address implementation) {
        implementation = deployStrategy();
        upgradeProxyByOwner(_owner, _proxy, implementation);

        return implementation;
    }

    function deployStrategy() private returns (address) {
        vm.startBroadcast();
        BoxV2 implementation = new BoxV2();
        vm.stopBroadcast();

        return address(implementation);
    }

    function upgradeProxyByOwner(address _owner, address _proxy, address _newImplementation) public {
        BoxV1 proxyContract = BoxV1(_proxy);
        uint64 nextVersion = proxyContract.getVersion() + 1;
        bytes memory data = abi.encodeWithSelector(BoxV2.initialize.selector, _owner, nextVersion); // set Owner and new Version

        vm.startBroadcast(_owner); // Only owner can upgrade proxy
        proxyContract.upgradeToAndCall(_newImplementation, data);
        vm.stopBroadcast();
    }
}
