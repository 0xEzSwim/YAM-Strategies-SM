// SPX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {CSMMock} from "../../test/mocks/CSMMock.sol";

contract DeployCSMToken is Script {
    address private token;

    function run(string memory _name, string memory _symbol, uint256 amount) external returns (address) {
        address admin = vm.envAddress("ADMIN_PUBLIC_KEY");

        vm.startBroadcast();
        token = address(new CSMMock(_name, _symbol));
        vm.stopBroadcast();

        if (block.chainid != 100) {
            // Gnosis chain
            vm.startBroadcast();
            CSMMock(token).mint(admin, amount);
            vm.stopBroadcast();
        }

        console.log(CSMMock(token).symbol(), "address:", token);
        console.log("\t=> Decimals:", CSMMock(token).decimals());

        return token;
    }
}
