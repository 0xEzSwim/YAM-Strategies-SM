// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {USDCMock} from "../../test/mocks/USDCMock.sol";

contract DeployUSDCToken is Script {
    address private asset;

    function run() external returns (address) {
        vm.startBroadcast();
        asset = address(new USDCMock());
        vm.stopBroadcast();
        console.log(USDCMock(asset).symbol(), "address:", asset);
        console.log("\t=> Decimals:", USDCMock(asset).decimals());

        return asset;
    }
}
