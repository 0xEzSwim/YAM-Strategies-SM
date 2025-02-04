// SPX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RealTokenYamUpgradeableV3, IRealTokenYamUpgradeableV3} from "../../src/markets/RealTokenYamUpgradeableV3.sol";
import {USDCMock} from "../../../test/mocks/USDCMock.sol";
import {RealTokenMock} from "../../../test/mocks/RealTokenMock.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract DeployRealTokenYAM is Script {
    function run(address owner) external returns (address) {
        (address proxy, address implementation) = _deploy(owner);
        console.log("_DeployRealTokenYAM");
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);

        return proxy;
    }

    function _deploy(address owner) private returns (address proxy, address implementation) {
        implementation = deployRealTokenYamUpgradeableV3();
        proxy = _deployProxyByOwner(owner, implementation);

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
        return _deployProxyByOwner(owner, implementation);
    }

    function _deployProxyByOwner(address owner, address implementation) private returns (address) {
        bytes memory data = abi.encodeWithSelector(RealTokenYamUpgradeableV3.initialize.selector, owner, owner); // set proxy admin & moderator
        vm.startBroadcast();
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vm.stopBroadcast();

        return address(proxy);
    }

    function setupMarket() public {
        address admin = vm.envAddress("ADMIN_PUBLIC_KEY");
        address moderator = vm.envAddress("MODERATOR_PUBLIC_KEY");

        // Get Underlying Asset
        address asset = DevOpsTools.get_most_recent_deployment("USDCMock", block.chainid);

        // Get TOKENS
        address rwaToken = DevOpsTools.get_most_recent_deployment("RealTokenMock", block.chainid);

        // Get Market
        address marketImplementation =
            DevOpsTools.get_most_recent_deployment("RealTokenYamUpgradeableV3", block.chainid);
        string memory marketString = Strings.toChecksumHexString(marketImplementation);
        address market = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", marketString, block.chainid);

        // Set up Whitelist for Market
        address[] memory whitelistedTokens = new address[](2);
        whitelistedTokens[0] = asset;
        whitelistedTokens[1] = rwaToken;
        IRealTokenYamUpgradeableV3.TokenType[] memory tokenTypes = new IRealTokenYamUpgradeableV3.TokenType[](2);
        tokenTypes[0] = IRealTokenYamUpgradeableV3.TokenType.ERC20WITHPERMIT;
        tokenTypes[1] = IRealTokenYamUpgradeableV3.TokenType.REALTOKEN;
        vm.startBroadcast(admin);
        RealTokenYamUpgradeableV3(market).toggleWhitelistWithType(whitelistedTokens, tokenTypes);
        vm.stopBroadcast();

        // Set up Market offers
        vm.startBroadcast(admin);
        // approve & create offer to sell 100 CSM-ALPHA for 14.05 USDC
        uint256 offerPrice = 5000 * uint256(10) ** (USDCMock(asset).decimals() - 2);
        uint256 offerAmount = 100 * uint256(10) ** RealTokenMock(rwaToken).decimals();
        RealTokenMock(rwaToken).approve(market, offerAmount);
        RealTokenYamUpgradeableV3(market).createOffer(rwaToken, asset, address(0), offerPrice, offerAmount);
        vm.stopBroadcast();

        uint256 offerCount = RealTokenYamUpgradeableV3(market).getOfferCount();
        console.log("# of offers on market:", offerCount);
        for (uint256 offerId = 0; offerId < offerCount; offerId++) {
            (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
                RealTokenYamUpgradeableV3(market).showOffer(offerId);
            console.log("__ offer #", offerId, "__");
            console.log("market offer's seller:", seller);
            console.log("market offer is private:", buyer == address(0));
            console.log("market offer tokens to send:", offerToken, amount);
            console.log("market offer tokens to receive:", buyerToken, price);
        }

        if (block.chainid == 31337) {
            vm.warp(block.timestamp + 1);
            vm.roll(block.number + 1); // can't buy an offer from the same block number.
        }
    }
}
