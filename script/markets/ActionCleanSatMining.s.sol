// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {CleanSatMining} from "../../src/markets/CleanSatMining.sol";
import {USDCMock} from "../../test/mocks/USDCMock.sol";
import {CSMMock} from "../../test/mocks/CSMMock.sol";

contract ActionCleanSatMining is Script {
    address public ADMIN = vm.envAddress("ADMIN_PUBLIC_KEY");
    address constant CSM_STRATEGY = 0x7860fa929e453A38115699dE11739C2ad42D09c5;
    address constant CSM_MARKET = 0xC588428fC4AfBa21B94ab158fc63E0D4d179D4CB;
    address constant USDC_TOKEN = 0x1197161d6e86A0F881B95E02B8DA07E56b6a751A;
    address constant CSM_ALPHA_TOKEN = 0x5A768Da857aD9b112631f88892CdE57E09AA8A6A;
    address constant CSM_DELTA_TOKEN = 0xC731074a0c0f078C6474049AF4d5560fa70D7F77;

    function createPublicSellingOfferForAlphaToken(uint256 _offerPrice, uint256 _offerAmount) public {
        _createPublicOffer(CSM_ALPHA_TOKEN, USDC_TOKEN, _offerPrice, _offerAmount);
    }

    function createPublicSellingOfferForDeltaToken(uint256 _offerPrice, uint256 _offerAmount) public {
        _createPublicOffer(CSM_DELTA_TOKEN, USDC_TOKEN, _offerPrice, _offerAmount);
    }

    function updatePublicSellingOfferForAlphaToken(uint256 _offerPrice, uint256 _offerAmount) public {
        _updatePublicOffer(0, _offerPrice, _offerAmount);
    }

    function updatePublicSellingOfferForDeltaToken(uint256 _offerPrice, uint256 _offerAmount) public {
        _updatePublicOffer(1, _offerPrice, _offerAmount);
    }

    function _createPublicOffer(address _offerToken, address _buyerToken, uint256 _offerPrice, uint256 _offerAmount)
        private
    {
        console.log("_createPublicOffer_");
        vm.startBroadcast(ADMIN);
        CSMMock(_offerToken).approve(CSM_MARKET, _offerAmount);
        CleanSatMining(CSM_MARKET).createOffer(_offerToken, _buyerToken, address(0), _offerPrice, _offerAmount);
        vm.stopBroadcast();
        console.log("\t=>market offer's seller:", ADMIN);
        console.log("\t=>market offer tokens to send:", _offerToken, _offerAmount);
        console.log("\t=>market offer tokens to receive:", _buyerToken, _offerPrice);
    }

    function _updatePublicOffer(uint256 _offerId, uint256 _offerPrice, uint256 _offerAmount) private {
        console.log("_updatePublicOffer_");
        vm.startBroadcast(ADMIN);
        CleanSatMining(CSM_MARKET).updateOffer(_offerId, _offerPrice, _offerAmount);
        vm.stopBroadcast();
        console.log("\t=>market offer has been updated");
    }
}
