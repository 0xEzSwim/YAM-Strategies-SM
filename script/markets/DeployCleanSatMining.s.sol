// SPX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CleanSatMining, ICleanSatMining} from "../../src/markets/CleanSatMining.sol";
import {USDCMock} from "../../../test/mocks/USDCMock.sol";
import {CSMMock} from "../../../test/mocks/CSMMock.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract DeployCleanSatMining is Script {
    function run(address owner) external returns (address) {
        (address proxy, address implementation) = _deploy(owner);
        console.log("_DeployCleanSatMining_");
        console.log("\t=>proxy address:", proxy);
        console.log("\t=>implementation address:", implementation);

        return proxy;
    }

    function _deploy(address owner) private returns (address proxy, address implementation) {
        implementation = deployCleanSatMining();
        proxy = _deployProxyByOwner(owner, implementation);

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
        return _deployProxyByOwner(owner, implementation);
    }

    function _deployProxyByOwner(address owner, address implementation) private returns (address) {
        bytes memory data = abi.encodeWithSelector(CleanSatMining.initialize.selector, owner, owner); // set proxy admin & moderator
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
        address csmAlpha = DevOpsTools.get_most_recent_deployment("CSMMock", "CSM-ALPHA.M", block.chainid);
        address csmDelta = DevOpsTools.get_most_recent_deployment("CSMMock", "CSM-DELTA.M", block.chainid);

        // Get Market
        address marketImplementation = DevOpsTools.get_most_recent_deployment("CleanSatMining", block.chainid);
        string memory marketString = Strings.toChecksumHexString(marketImplementation);
        address market = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", marketString, block.chainid);

        // Set up Whitelist for CSM Market
        address[] memory whitelistedTokens = new address[](3);
        whitelistedTokens[0] = asset;
        whitelistedTokens[1] = csmAlpha;
        whitelistedTokens[2] = csmDelta;
        ICleanSatMining.TokenType[] memory tokenTypes = new ICleanSatMining.TokenType[](3);
        tokenTypes[0] = ICleanSatMining.TokenType.ERC20WITHPERMIT;
        tokenTypes[1] = ICleanSatMining.TokenType.CLEANSATMINING;
        tokenTypes[2] = ICleanSatMining.TokenType.CLEANSATMINING;
        vm.startBroadcast(admin);
        CleanSatMining(market).toggleWhitelistWithType(whitelistedTokens, tokenTypes);
        vm.stopBroadcast();

        // Set up Market offers
        vm.startBroadcast(admin);
        // approve & create offer to sell 100 CSM-ALPHA for 14.05 USDC
        uint256 offerPrice = 1405 * uint256(10) ** (USDCMock(asset).decimals() - 2);
        uint256 offerAmount = 100 * uint256(10) ** CSMMock(csmAlpha).decimals();
        CSMMock(csmAlpha).approve(market, offerAmount);
        CleanSatMining(market).createOffer(csmAlpha, asset, address(0), offerPrice, offerAmount);
        // approve & create offer to sell 250 CSM-DELTA for 7.44 USDC
        offerPrice = 744 * uint256(10) ** (USDCMock(asset).decimals() - 2);
        offerAmount = 250 * uint256(10) ** CSMMock(csmDelta).decimals();
        CSMMock(csmDelta).approve(market, offerAmount);
        CleanSatMining(market).createOffer(csmDelta, asset, address(0), offerPrice, offerAmount);
        vm.stopBroadcast();

        uint256 offerCount = CleanSatMining(market).getOfferCount();
        console.log("# of offers on market:", offerCount);
        for (uint256 offerId = 0; offerId < offerCount; offerId++) {
            (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
                CleanSatMining(market).showOffer(offerId);
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
