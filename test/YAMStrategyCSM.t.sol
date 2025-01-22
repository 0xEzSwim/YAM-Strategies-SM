// SPX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {DeployYAMStrategyCSM} from "../script/strategies/cleanSatMining/DeployYAMStrategyCSM.s.sol";
import {DeployCleanSatMining} from "../script/markets/DeployCleanSatMining.s.sol";
import {DeployUSDCToken} from "../script/tokens/DeployUSDCToken.s.sol";
import {DeployCSMToken} from "../script/tokens/DeployCSMToken.s.sol";
import {YAMStrategyCSM} from "../src/strategies/YAMStrategyCSM.sol";
import {CleanSatMining, ICleanSatMining} from "../src/markets/CleanSatMining.sol";
import {USDCMock} from "./mocks/USDCMock.sol";
import {CSMMock} from "./mocks/CSMMock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract YAMStrategyCSMTest is Test {
    address public ADMIN = vm.envAddress("ADMIN_PUBLIC_KEY");
    address public MODERATOR = vm.envAddress("MODERATOR_PUBLIC_KEY");
    address public BUYER = makeAddr("buyer");
    address public asset;
    address public csmAlpha;
    address public csmDelta;
    address public market;
    address public startegy;
    uint256 public initialAssetBalance;

    function setUp() external {
        console.log("-- Setup Start --");
        // Set up CSM strategy
        DeployYAMStrategyCSM deployerStrategy = new DeployYAMStrategyCSM();
        startegy = deployerStrategy.run("Undervalued");
        market = YAMStrategyCSM(startegy).getCsmMarket();
        asset = YAMStrategyCSM(startegy).asset();
        csmAlpha = YAMStrategyCSM(startegy).getCsmToken(0);
        csmDelta = YAMStrategyCSM(startegy).getCsmToken(1);

        // Set up asset
        initialAssetBalance = 1000 * uint256(10) ** USDCMock(asset).decimals(); // 1000.000_000
        vm.startPrank(ADMIN);
        USDCMock(asset).transfer(BUYER, initialAssetBalance);
        vm.stopPrank();
        console.log(BUYER, USDCMock(asset).symbol(), "amount:", USDCMock(asset).balanceOf(BUYER));
        console.log(MODERATOR, USDCMock(asset).symbol(), "amount:", USDCMock(asset).balanceOf(MODERATOR));
        console.log(ADMIN, USDCMock(asset).symbol(), "amount:", USDCMock(asset).balanceOf(ADMIN));
        console.log("");

        console.log("-- Setup End --", "\n");
    }

    modifier initDeposit() {
        vm.startPrank(ADMIN);
        USDCMock(asset).approve(startegy, initialAssetBalance);
        YAMStrategyCSM(startegy).deposit(initialAssetBalance, ADMIN);
        vm.stopPrank();

        vm.startPrank(BUYER);
        USDCMock(asset).approve(startegy, initialAssetBalance);
        YAMStrategyCSM(startegy).deposit(initialAssetBalance, BUYER);
        vm.stopPrank();
        _;
    }

    /**
     *
     * DEPOSIT *
     *
     */
    function test_strategyDeposit() external initDeposit {
        console.log("-- test_strategyDeposit START --");

        uint256 strategyAUM = YAMStrategyCSM(startegy).totalAssets();
        uint256 buyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        uint256 decimals = YAMStrategyCSM(startegy).decimals();
        console.log("Startegy assets under managment:", strategyAUM);
        console.log("BUYER assets in vault:", YAMStrategyCSM(startegy).convertToAssets(buyerShares));
        console.log("Startegy total shares:", YAMStrategyCSM(startegy).totalSupply());
        console.log("BUYER shares owned:", buyerShares);

        // TEST
        uint256 buyerSharesPerc = (buyerShares * uint256(10) ** decimals / YAMStrategyCSM(startegy).totalSupply());
        console.log("BUYER shares percent:", buyerSharesPerc);
        assertEq(buyerSharesPerc, 5 * uint256(10) ** (decimals - 1)); // check if BUYER has 0.5 shares of YAMStrategyCSM

        console.log("-- test_strategyDeposit END --", "\n");
    }

    /**
     *
     * TRANSACTION *
     *
     */
    function test_strategyAmountTooLowToBuy() external {
        console.log("-- test_strategyNotEnoughAssetToBuy START --");
        // Deposit 0.000_001 Asset into Strategy
        vm.startPrank(BUYER);
        USDCMock(asset).approve(startegy, 1);
        YAMStrategyCSM(startegy).deposit(1, BUYER);
        vm.stopPrank();
        uint256 strategyAUM = YAMStrategyCSM(startegy).totalAssets();
        console.log("Startegy assets under managment:", strategyAUM);
        console.log("Startegy total shares emitted:", YAMStrategyCSM(startegy).totalSupply());

        // Get Offer
        uint256 offerId = 0;
        (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);
        console.log("market offer's seller:", seller);
        console.log("market offer is private:", buyer == address(0));
        console.log("market offer tokens to send:", offerToken, amount);
        console.log("market offer tokens to receive:", buyerToken, price);

        // Buy triggered by the bot (MODERATOR) only
        // TESTS
        vm.expectRevert(YAMStrategyCSM.YAMStrategy__AmountToBuyIsToLow.selector);
        vm.prank(MODERATOR);
        YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        console.log("-- test_strategyNotEnoughAssetToBuy END --", "\n");
    }

    function test_strategyNotEnoughUndelyingAssetToBuy() external initDeposit {
        console.log("-- test_strategyNotEnoughUndelyingAssetToBuy START --");

        uint256 strategyAUM = YAMStrategyCSM(startegy).totalAssets();
        uint256 offerId = 0;
        address offerToken;
        address buyerToken;
        address seller;
        address buyer;
        uint256 price;
        uint256 amount;
        while (strategyAUM > 1) {
            console.log("strategyAUM:", strategyAUM);
            console.log("offerId:", offerId);
            (offerToken, buyerToken, seller, buyer, price, amount) = CleanSatMining(market).showOffer(offerId);

            // Buy triggered by THE BOT only
            vm.prank(MODERATOR);
            uint256 amountToBuy =
                YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);
            console.log("offer amount Bought:", amountToBuy);
            (,,,,, uint256 _availableAmount) = CleanSatMining(market).showOffer(offerId);
            console.log("offer amount remaining:", _availableAmount);

            if (_availableAmount == 0) {
                offerId++;
            }

            strategyAUM = YAMStrategyCSM(startegy).totalAssets();
        }

        console.log("strategyAUM:", strategyAUM);
        // Buy when asset is 0;
        // TESTS
        vm.expectRevert(YAMStrategyCSM.YAMStrategy__AmountToBuyIsToLow.selector);
        vm.prank(MODERATOR);
        YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        console.log("-- test_strategyNotEnoughUndelyingAssetToBuy END --", "\n");
    }

    function test_strategyBuy(uint256 _offerId) external initDeposit {
        console.log("-- test_strategyBuy START --");
        uint256 offerCount = CleanSatMining(market).getOfferCount();
        if (_offerId >= offerCount) {
            console.log("Offer doesn't exist");
            console.log("-- test_strategyBuy END --", "\n");
            return;
        }
        uint256 strategyAUM = YAMStrategyCSM(startegy).totalAssets();

        // Get Offer
        (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(_offerId);
        console.log("market offer's seller:", seller);
        console.log("market offer is private:", buyer == address(0));
        console.log("market offer tokens to send:", offerToken, amount);
        console.log("market offer tokens to receive:", buyerToken, price);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(_offerId, offerToken, buyerToken, price, amount);

        // TESTS
        uint256 newStrategyAUM = YAMStrategyCSM(startegy).totalAssets();
        console.log("Strategy AUM AFTER buy:", newStrategyAUM);
        assertEq(newStrategyAUM, strategyAUM - ((amountToBuy * price) / (uint256(10) ** ERC20(offerToken).decimals())));

        uint256 strategyCsmAlphaUM = CSMMock(csmAlpha).balanceOf(startegy);
        uint256 strategyCsmBetaUM = CSMMock(csmDelta).balanceOf(startegy);
        uint256 strategyCsmUM = strategyCsmAlphaUM > strategyCsmBetaUM ? strategyCsmAlphaUM : strategyCsmBetaUM;
        console.log("Strategy CSM UM AFTER buy:", strategyCsmUM);
        assertEq(strategyCsmUM, amountToBuy);

        console.log("-- test_strategyBuy END --", "\n");
    }

    /**
     *
     * WITHDRAW *
     *
     */
    function test_strategyRedeemAll() external initDeposit {
        console.log("-- test_strategyRedeemAll START --");

        // Get Offer
        uint256 offerId = 0;
        (address offerToken, address buyerToken,,, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // Simulate pasage of time
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Redeem
        uint256 buyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);
        uint256 buyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", buyerCSMTokens);
        vm.startPrank(BUYER);
        YAMStrategyCSM(startegy).redeem(buyerShares, BUYER, BUYER);
        vm.stopPrank();

        // TEST
        uint256 newBuyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", newBuyerShares);
        assertEq(newBuyerShares, 0);

        uint256 newBuyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", newBuyerAssetTokens);
        assertGt(newBuyerAssetTokens, buyerAssetTokens);

        uint256 newBuyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", newBuyerCSMTokens);
        assertGt(newBuyerCSMTokens, 0);

        console.log("-- test_strategyRedeemAll END --", "\n");
    }

    function test_strategyRedeemRandom(uint256 _sharesToRedeem) external initDeposit {
        console.log("-- test_strategyRedeemRandom START:", _sharesToRedeem, "--");

        // Get Offer
        uint256 offerId = 0;
        (address offerToken, address buyerToken,,, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // Simulate pasage of time
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Redeem
        uint256 buyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        if (_sharesToRedeem > buyerShares) {
            console.log("-- shares to redeem is too high");
            console.log("-- test_strategyRedeemRandom END --", "\n");
            return;
        }
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);
        uint256 buyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", buyerCSMTokens);
        vm.prank(BUYER);
        YAMStrategyCSM(startegy).redeem(_sharesToRedeem, BUYER, BUYER);

        // TEST
        uint256 newBuyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", newBuyerShares);
        assertLe(newBuyerShares, buyerShares);

        uint256 newBuyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", newBuyerAssetTokens);
        assertGe(newBuyerAssetTokens, buyerAssetTokens);

        uint256 newBuyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", newBuyerCSMTokens);
        assertGe(newBuyerCSMTokens, 0);

        console.log("-- test_strategyRedeemRandom END --", "\n");
    }

    function test_strategyWithdrawAll() external initDeposit {
        console.log("-- test_strategyWithdrawAll START --");

        // Get Offer
        uint256 offerId = 0;
        (address offerToken, address buyerToken,,, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // Simulate pasage of time
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Withdraw
        uint256 buyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        uint256 buyerAssetsInVault = YAMStrategyCSM(startegy).convertToAssets(buyerShares);
        console.log("BUYER Asset tokens in vault:", buyerAssetsInVault);
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);
        uint256 buyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", buyerCSMTokens);
        vm.startPrank(BUYER);
        YAMStrategyCSM(startegy).withdraw(buyerAssetsInVault, BUYER, BUYER);
        vm.stopPrank();

        // TEST
        uint256 newBuyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", newBuyerShares);
        assertLt(newBuyerShares, uint256(10) ** YAMStrategyCSM(startegy).decimals());

        uint256 newBuyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", newBuyerAssetTokens);
        assertGt(newBuyerAssetTokens, buyerAssetTokens);

        uint256 newBuyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", newBuyerCSMTokens);
        assertGt(newBuyerCSMTokens, 0);

        console.log("-- test_strategyWithdrawAll END --", "\n");
    }

    function test_strategyWithdrawRandom(uint256 _assetsToWithdraw) external initDeposit {
        console.log("-- test_strategyWithdrawRandom START:", _assetsToWithdraw, "--");

        // Get Offer
        uint256 offerId = 0;
        (address offerToken, address buyerToken,,, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // Simulate pasage of time
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Withdraw
        uint256 buyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        if (_assetsToWithdraw > YAMStrategyCSM(startegy).convertToAssets(buyerShares)) {
            console.log("-- assets to withdraw is too high");
            console.log("-- test_strategyWithdrawRandom END --", "\n");
            return;
        }
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);
        uint256 buyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", buyerCSMTokens);
        vm.prank(BUYER);
        YAMStrategyCSM(startegy).withdraw(_assetsToWithdraw, BUYER, BUYER);

        // TEST
        uint256 newBuyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", newBuyerShares);
        assertLe(newBuyerShares, buyerShares);

        uint256 newBuyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", newBuyerAssetTokens);
        assertGe(newBuyerAssetTokens, buyerAssetTokens);

        uint256 newBuyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", newBuyerCSMTokens);
        assertGe(newBuyerCSMTokens, 0);

        console.log("-- test_strategyWithdrawRandom END --", "\n");
    }

    /**
     *
     * PAUSE *
     *
     */
    function test_BuyPauseAndUnPause() external initDeposit {
        console.log("-- test_BuyPauseAndUnPause START --");

        uint256 strategyAUM = YAMStrategyCSM(startegy).totalAssets();

        // PAUSE
        vm.prank(ADMIN);
        YAMStrategyCSM(startegy).pause();

        // Get Offer
        uint256 offerId = 0;
        (address offerToken, address buyerToken,,, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        // TESTS
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(MODERATOR);
        YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // UNPAUSE
        vm.prank(ADMIN);
        YAMStrategyCSM(startegy).unpause();

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            YAMStrategyCSM(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // TESTS
        uint256 newStrategyAUM = YAMStrategyCSM(startegy).totalAssets();
        console.log("Strategy AUM AFTER buy:", newStrategyAUM);
        assertEq(newStrategyAUM, strategyAUM - ((amountToBuy * price) / (uint256(10) ** ERC20(offerToken).decimals())));

        uint256 strategyCsmAlphaUM = CSMMock(csmAlpha).balanceOf(startegy);
        uint256 strategyCsmBetaUM = CSMMock(csmDelta).balanceOf(startegy);
        uint256 strategyCsmUM = strategyCsmAlphaUM > strategyCsmBetaUM ? strategyCsmAlphaUM : strategyCsmBetaUM;
        console.log("Strategy CSM UM AFTER buy:", strategyCsmUM);
        assertEq(strategyCsmUM, amountToBuy);

        console.log("-- test_BuyPauseAndUnPause END --", "\n");
    }

    function test_RedeemPauseAndUnPause() external initDeposit {
        console.log("-- test_RedeemPauseAndUnPause START --");

        uint256 buyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);

        // PAUSE
        vm.prank(ADMIN);
        YAMStrategyCSM(startegy).pause();

        // Buy triggered by THE BOT only
        // TESTS
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(BUYER);
        YAMStrategyCSM(startegy).redeem(buyerShares, BUYER, BUYER);

        // UNPAUSE
        vm.prank(ADMIN);
        YAMStrategyCSM(startegy).unpause();

        // Redeem
        vm.prank(BUYER);
        YAMStrategyCSM(startegy).redeem(buyerShares, BUYER, BUYER);

        // TEST
        uint256 newBuyerShares = YAMStrategyCSM(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", newBuyerShares);
        assertEq(newBuyerShares, 0);

        uint256 newBuyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", newBuyerAssetTokens);
        assertGt(newBuyerAssetTokens, buyerAssetTokens);

        console.log("-- test_RedeemPauseAndUnPause END --", "\n");
    }
}
