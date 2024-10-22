// SPX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {DeployBox} from "../script/box/DeployBox.s.sol";
import {UpgradeBox} from "../script/box/UpgradeBox.s.sol";
import {BoxV1} from "../src/box/BoxV1.sol";
import {BoxV2} from "../src/box/BoxV2.sol";

contract DeployAndUpgrade is Test {
    DeployBox public deployer;
    UpgradeBox public upgrader;
    address public OWNER = makeAddr("owner");

    address public proxy;

    function setUp() external {
        deployer = new DeployBox();
        upgrader = new UpgradeBox();
        console.log("deployer address:", OWNER);
        proxy = deployer.run(OWNER);
        console.log("proxy owner address:", BoxV1(proxy).owner());
    }

    function test_startAsV1() external {
        vm.expectRevert();
        BoxV2(proxy).setNumber(10);

        console.log(BoxV1(proxy).getVersion());
    }

    function test_onlyOwnerCanUpgrade() external {
        address notOwner = makeAddr("not_owner");
        BoxV2 box2 = new BoxV2();
        console.log("not owner address:", notOwner);

        vm.expectRevert();
        upgrader.upgradeProxyByOwner(notOwner, proxy, address(box2));

        console.log("Ok: Could not upgrade with adress", notOwner);
    }

    function test_upgrades() external {
        BoxV2 box2 = new BoxV2();

        uint256 expectedNumber = 7;
        uint256 expectedVersion = BoxV1(proxy).getVersion() + 1;

        upgrader.upgradeProxyByOwner(OWNER, proxy, address(box2));
        BoxV2(proxy).setNumber(expectedNumber);
        assertEq(BoxV2(proxy).getNumber(), expectedNumber);
        assertEq(BoxV2(proxy).getVersion(), expectedVersion);

        console.log("new owner address:", BoxV2(proxy).owner());
    }
}
