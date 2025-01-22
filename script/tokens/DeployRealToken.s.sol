// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {RealTokenMock} from "../../test/mocks/RealTokenMock.sol";

contract DeployRealToken is Script {
    address private token;

    function run(string memory _name, string memory _symbol) external returns (address) {
        vm.startBroadcast();
        token = address(new RealTokenMock(_name, _symbol));
        vm.stopBroadcast();
        console.log(RealTokenMock(token).symbol(), "address:", token);
        console.log("\t=> Decimals:", RealTokenMock(token).decimals());

        return token;
    }
}
