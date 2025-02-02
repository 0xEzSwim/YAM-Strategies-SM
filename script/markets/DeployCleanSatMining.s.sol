// SPX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CleanSatMining} from "../../src/markets/CleanSatMining.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract DeployCleanSatMining is Script {
    function run(address owner) external returns (address) {
        console.log("_DeployCleanSatMining_");
        (address proxy, address implementation) = _deploy(owner);
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);

        return proxy;
    }

    function _deploy(address owner) private returns (address proxy, address implementation) {
        implementation = deployCleanSatMining();
        proxy = deployProxyByOwner(owner);

        return (proxy, implementation);
    }

    function deployCleanSatMining() public returns (address) {
        vm.startBroadcast();
        CleanSatMining implementation = new CleanSatMining();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(address owner) public returns (address) {
        address implementation = DevOpsTools.get_most_recent_deployment("CleanSatMining", block.chainid);
        bytes memory data = abi.encodeWithSelector(CleanSatMining.initialize.selector, owner, owner); // set proxy admin & moderator
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
