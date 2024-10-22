// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {BoxV1} from "../../src/box/BoxV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployBox is Script {
    function run(address _owner) external returns (address) {
        (address proxy, address implementation) = deploy(_owner);
        console.log("proxy address:", proxy);
        console.log("implementation address:", implementation);

        return proxy;
    }

    function deploy(address _owner) private returns (address proxy, address implementation) {
        implementation = deployStrategy();
        proxy = deployProxyByOwner(_owner, implementation);

        return (proxy, implementation);
    }

    function deployStrategy() private returns (address) {
        vm.startBroadcast();
        BoxV1 implementation = new BoxV1();
        vm.stopBroadcast();

        return address(implementation);
    }

    function deployProxyByOwner(address _owner, address _implementation) private returns (address) {
        bytes memory data = abi.encodeWithSelector(BoxV1.initialize.selector, _owner); // set proxy owner
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(address(_implementation), data);
        vm.stopBroadcast();
        return address(proxy);
    }
}
