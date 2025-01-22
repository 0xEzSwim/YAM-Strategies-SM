// SPX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {USDCMock} from "../../test/mocks/USDCMock.sol";

contract DeployUSDCToken is Script {
    address private asset;

    function run() external returns (address) {
        address admin = vm.envAddress("ADMIN_PUBLIC_KEY");
        address moderator = vm.envAddress("MODERATOR_PUBLIC_KEY");

        vm.startBroadcast();
        asset = address(new USDCMock());
        USDCMock(asset).mint(admin, 1000000 * uint256(10) ** USDCMock(asset).decimals()); // 1,000,000.000_000
        vm.stopBroadcast();

        vm.startBroadcast(admin);
        USDCMock(asset).transfer(moderator, 10000 * uint256(10) ** USDCMock(asset).decimals()); // 10,000.000_000
        vm.stopBroadcast();

        console.log(USDCMock(asset).symbol(), "address:", asset);
        console.log("\t=> Decimals:", USDCMock(asset).decimals());

        return asset;
    }
}
