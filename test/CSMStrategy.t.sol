// SPX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {DeployCleanSatMining} from "../script/market/DeployCleanSatMining.s.sol";
import {DeployCSMStrategy} from "../script/DeployCSMStrategy.s.sol";
import {CSMStrategy} from "../src/CSMStrategy.sol";
import {CleanSatMining, ICleanSatMining} from "../src/market/CleanSatMining.sol";
import {USDCMock} from "./mocks/USDCMock.sol";
import {CSMMock} from "./mocks/CSMMock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract CSMStrategyTest is Test {
    address public OWNER = makeAddr("owner");
    address public MODERATOR = makeAddr("moderator");
    address public BUYER = makeAddr("buyer");
    address public SELLER = makeAddr("seller");
    address public asset;
    address public csmAlpha;
    address public csmBeta;
    address public market;
    address public startegy;
    uint256 public initialAssetBalance;
    uint256 public initialCSMBalance;

    function setUp() external {
        console.log("-- Setup Start --");
        // Set up USDC tokens
        asset = address(new USDCMock());
        initialAssetBalance = 1000 * uint256(10) ** USDCMock(asset).decimals(); // 1000.000_000
        console.log("asset address:", asset, "\n\t=> Decimals:", USDCMock(asset).decimals());

        // Set up CSM token ALPHA
        csmAlpha = address(new CSMMock("CleanSatMining ALPHA", "CSM-ALPHA"));
        initialCSMBalance = 100 * uint256(10) ** CSMMock(csmAlpha).decimals(); // 100.000_000_000
        console.log("csmAlpha address:", csmAlpha, "\n\t=> Decimals:", CSMMock(csmAlpha).decimals());

        // Set up CSM token BETA
        csmBeta = address(new CSMMock("CleanSatMining BETA", "CSM-BETA"));
        initialCSMBalance = 100 * uint256(10) ** CSMMock(csmBeta).decimals(); // 100.000_000_000
        console.log("csmBeta address:", csmBeta, "\n\t=> Decimals:", CSMMock(csmBeta).decimals());

        // Set up Marketplace
        DeployCleanSatMining deployerMarket = new DeployCleanSatMining();
        market = deployerMarket.run(OWNER);
        console.log("Market address:", market);

        // Set up Startegy
        address[] memory csmTokens = new address[](2);
        csmTokens[0] = csmAlpha;
        csmTokens[1] = csmBeta;
        DeployCSMStrategy deployerStrategy = new DeployCSMStrategy();
        startegy = deployerStrategy.run(OWNER, MODERATOR, asset, market, csmTokens);
        console.log("Startegy address:", startegy);
        console.log("Is asset a CSM token:", CSMStrategy(startegy).isCSMToken(asset));
        console.log("Is csmAlpha a CSM token:", CSMStrategy(startegy).isCSMToken(csmAlpha));
        console.log("Is csmBeta a CSM token:", CSMStrategy(startegy).isCSMToken(csmBeta), "\n");

        // Set up assets
        USDCMock(asset).mint(BUYER, initialAssetBalance);
        USDCMock(asset).mint(MODERATOR, initialAssetBalance);
        console.log("BUYER asset amount:", USDCMock(asset).balanceOf(BUYER));
        console.log("SELLER asset amount:", USDCMock(asset).balanceOf(SELLER));
        console.log("OWNER asset amount:", USDCMock(asset).balanceOf(MODERATOR), "\n");

        // Set up CSM tokens
        CSMMock(csmAlpha).mint(SELLER, initialCSMBalance);
        CSMMock(csmBeta).mint(SELLER, initialCSMBalance);
        CSMMock(csmAlpha).mint(MODERATOR, initialCSMBalance);
        CSMMock(csmBeta).mint(MODERATOR, initialCSMBalance);
        console.log(
            "BUYER csmAlpha amount:",
            CSMMock(csmAlpha).balanceOf(BUYER),
            "\n  BUYER csmBeta amount:",
            CSMMock(csmBeta).balanceOf(BUYER)
        );
        console.log(
            "SELLER csmAlpha amount:",
            CSMMock(csmAlpha).balanceOf(SELLER),
            "\n  SELLER csmBeta amount:",
            CSMMock(csmBeta).balanceOf(SELLER)
        );
        console.log(
            "OWNER csmAlpha amount:",
            CSMMock(csmAlpha).balanceOf(MODERATOR),
            "\n  OWNER csmBeta amount:",
            CSMMock(csmBeta).balanceOf(MODERATOR)
        );

        // Set up Market offers
        address[] memory tokens = new address[](3);
        tokens[0] = asset;
        tokens[1] = csmAlpha;
        tokens[2] = csmBeta;
        ICleanSatMining.TokenType[] memory types = new ICleanSatMining.TokenType[](3);
        types[0] = ICleanSatMining.TokenType.ERC20WITHPERMIT;
        types[1] = ICleanSatMining.TokenType.CLEANSATMINING;
        types[2] = ICleanSatMining.TokenType.CLEANSATMINING;
        vm.prank(OWNER);
        CleanSatMining(market).toggleWhitelistWithType(tokens, types);
        console.log(
            "Is asset type ERC20WITHPERMIT:",
            CleanSatMining(market).getTokenType(asset) == ICleanSatMining.TokenType.ERC20WITHPERMIT
        );
        console.log(
            "Is csmAlpha type CLEANSATMINING:",
            CleanSatMining(market).getTokenType(csmAlpha) == ICleanSatMining.TokenType.CLEANSATMINING
        );
        console.log(
            "Is csmBeta type CLEANSATMINING:",
            CleanSatMining(market).getTokenType(csmBeta) == ICleanSatMining.TokenType.CLEANSATMINING
        );

        vm.startPrank(SELLER);
        uint256 offerPrice = 100 * uint256(10) ** USDCMock(asset).decimals();
        uint256 offerAmount = 10 * uint256(10) ** CSMMock(csmAlpha).decimals();
        // approve & create offer to sell 10 CSM-ALPHA for 100 USDC
        CSMMock(csmAlpha).approve(market, offerAmount);
        CleanSatMining(market).createOffer(csmAlpha, asset, address(0), offerPrice, offerAmount);
        // approve & create offer to sell 7 CSM-BETA for 150 USDC
        offerPrice = 150 * uint256(10) ** USDCMock(asset).decimals();
        offerAmount = 7 * uint256(10) ** CSMMock(csmBeta).decimals();
        CSMMock(csmBeta).approve(market, offerAmount);
        CleanSatMining(market).createOffer(csmBeta, asset, address(0), offerPrice, offerAmount);
        vm.stopPrank();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1); // can't buy an offer from the same block number.
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

        console.log("-- Setup End --", "\n");
    }

    modifier initDeposit() {
        vm.startPrank(MODERATOR);
        USDCMock(asset).approve(startegy, initialAssetBalance);
        CSMStrategy(startegy).deposit(initialAssetBalance, MODERATOR);
        vm.stopPrank();

        vm.startPrank(BUYER);
        USDCMock(asset).approve(startegy, initialAssetBalance);
        CSMStrategy(startegy).deposit(initialAssetBalance, BUYER);
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

        uint256 strategyAUM = CSMStrategy(startegy).totalAssets();
        uint256 buyerShares = CSMStrategy(startegy).balanceOf(BUYER);
        uint256 decimals = CSMStrategy(startegy).decimals();
        console.log("Startegy assets under managment:", strategyAUM);
        console.log("BUYER assets in vault:", CSMStrategy(startegy).convertToAssets(buyerShares));
        console.log("Startegy total shares:", CSMStrategy(startegy).totalSupply());
        console.log("BUYER shares owned:", buyerShares);

        // TEST
        uint256 buyerSharesPerc = (buyerShares * uint256(10) ** decimals / CSMStrategy(startegy).totalSupply());
        console.log("BUYER shares percent:", buyerSharesPerc);
        assertEq(buyerSharesPerc, 5 * uint256(10) ** (decimals - 1)); // check if BUYER has 0.5 shares of CSMStrategy

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
        CSMStrategy(startegy).deposit(1, BUYER);
        vm.stopPrank();
        uint256 strategyAUM = CSMStrategy(startegy).totalAssets();
        console.log("Startegy assets under managment:", strategyAUM);
        console.log("Startegy total shares emitted:", CSMStrategy(startegy).totalSupply());

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
        vm.expectRevert(CSMStrategy.CSMStrategy__AmountToBuyIsToLow.selector);
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        console.log("-- test_strategyNotEnoughAssetToBuy END --", "\n");
    }

    function test_strategyNotEnoughUndelyingAssetToBuy() external initDeposit {
        console.log("-- test_strategyNotEnoughUndelyingAssetToBuy START --");

        uint256 strategyAUM = CSMStrategy(startegy).totalAssets();
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
                CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);
            console.log("offer amount Bought:", amountToBuy);
            (,,,,, uint256 _availableAmount) = CleanSatMining(market).showOffer(offerId);
            console.log("offer amount remaining:", _availableAmount);

            if (_availableAmount == 0) {
                offerId++;
            }

            strategyAUM = CSMStrategy(startegy).totalAssets();
        }

        console.log("strategyAUM:", strategyAUM);
        // Buy when asset is 0;
        // TESTS
        vm.expectRevert(CSMStrategy.CSMStrategy__AmountToBuyIsToLow.selector);
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

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
        uint256 strategyAUM = CSMStrategy(startegy).totalAssets();

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
            CSMStrategy(startegy).buyMaxCSMTokenFromOffer(_offerId, offerToken, buyerToken, price, amount);

        // TESTS
        uint256 newStrategyAUM = CSMStrategy(startegy).totalAssets();
        console.log("Strategy AUM AFTER buy:", newStrategyAUM);
        assertEq(newStrategyAUM, strategyAUM - ((amountToBuy * price) / (uint256(10) ** ERC20(offerToken).decimals())));

        uint256 strategyCsmAlphaUM = CSMMock(csmAlpha).balanceOf(startegy);
        uint256 strategyCsmBetaUM = CSMMock(csmBeta).balanceOf(startegy);
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
        (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // Simulate pasage of time
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Redeem
        uint256 buyerShares = CSMStrategy(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);
        uint256 buyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", buyerCSMTokens);
        vm.startPrank(BUYER);
        CSMStrategy(startegy).redeem(buyerShares, BUYER, BUYER);
        vm.stopPrank();

        // TEST
        uint256 newBuyerShares = CSMStrategy(startegy).balanceOf(BUYER);
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
        (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // Simulate pasage of time
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Redeem
        uint256 buyerShares = CSMStrategy(startegy).balanceOf(BUYER);
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
        CSMStrategy(startegy).redeem(_sharesToRedeem, BUYER, BUYER);

        // TEST
        uint256 newBuyerShares = CSMStrategy(startegy).balanceOf(BUYER);
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
        (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // Simulate pasage of time
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Withdraw
        uint256 buyerShares = CSMStrategy(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        uint256 buyerAssetsInVault = CSMStrategy(startegy).convertToAssets(buyerShares);
        console.log("BUYER Asset tokens in vault:", buyerAssetsInVault);
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);
        uint256 buyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", buyerCSMTokens);
        vm.startPrank(BUYER);
        CSMStrategy(startegy).withdraw(buyerAssetsInVault, BUYER, BUYER);
        vm.stopPrank();

        // TEST
        uint256 newBuyerShares = CSMStrategy(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", newBuyerShares);
        assertLt(newBuyerShares, uint256(10) ** CSMStrategy(startegy).decimals());

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
        (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // Simulate pasage of time
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Withdraw
        uint256 buyerShares = CSMStrategy(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        if (_assetsToWithdraw > CSMStrategy(startegy).convertToAssets(buyerShares)) {
            console.log("-- assets to withdraw is too high");
            console.log("-- test_strategyWithdrawRandom END --", "\n");
            return;
        }
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);
        uint256 buyerCSMTokens = CSMMock(csmAlpha).balanceOf(BUYER);
        console.log("BUYER CSM tokens:", buyerCSMTokens);
        vm.prank(BUYER);
        CSMStrategy(startegy).withdraw(_assetsToWithdraw, BUYER, BUYER);

        // TEST
        uint256 newBuyerShares = CSMStrategy(startegy).balanceOf(BUYER);
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

        uint256 strategyAUM = CSMStrategy(startegy).totalAssets();

        // PAUSE
        vm.prank(OWNER);
        CSMStrategy(startegy).pause();

        // Get Offer
        uint256 offerId = 0;
        (address offerToken, address buyerToken, address seller, address buyer, uint256 price, uint256 amount) =
            CleanSatMining(market).showOffer(offerId);

        // Buy triggered by THE BOT only
        // TESTS
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(MODERATOR);
        uint256 amountToBuy =
            CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // UNPAUSE
        vm.prank(OWNER);
        CSMStrategy(startegy).unpause();

        // Buy triggered by THE BOT only
        vm.prank(MODERATOR);
        amountToBuy = CSMStrategy(startegy).buyMaxCSMTokenFromOffer(offerId, offerToken, buyerToken, price, amount);

        // TESTS
        uint256 newStrategyAUM = CSMStrategy(startegy).totalAssets();
        console.log("Strategy AUM AFTER buy:", newStrategyAUM);
        assertEq(newStrategyAUM, strategyAUM - ((amountToBuy * price) / (uint256(10) ** ERC20(offerToken).decimals())));

        uint256 strategyCsmAlphaUM = CSMMock(csmAlpha).balanceOf(startegy);
        uint256 strategyCsmBetaUM = CSMMock(csmBeta).balanceOf(startegy);
        uint256 strategyCsmUM = strategyCsmAlphaUM > strategyCsmBetaUM ? strategyCsmAlphaUM : strategyCsmBetaUM;
        console.log("Strategy CSM UM AFTER buy:", strategyCsmUM);
        assertEq(strategyCsmUM, amountToBuy);

        console.log("-- test_BuyPauseAndUnPause END --", "\n");
    }

    function test_RedeemPauseAndUnPause() external initDeposit {
        console.log("-- test_RedeemPauseAndUnPause START --");

        uint256 buyerShares = CSMStrategy(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", buyerShares);
        uint256 buyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", buyerAssetTokens);

        // PAUSE
        vm.prank(OWNER);
        CSMStrategy(startegy).pause();

        // Buy triggered by THE BOT only
        // TESTS
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(BUYER);
        CSMStrategy(startegy).redeem(buyerShares, BUYER, BUYER);

        // UNPAUSE
        vm.prank(OWNER);
        CSMStrategy(startegy).unpause();

        // Redeem
        vm.prank(BUYER);
        CSMStrategy(startegy).redeem(buyerShares, BUYER, BUYER);

        // TEST
        uint256 newBuyerShares = CSMStrategy(startegy).balanceOf(BUYER);
        console.log("BUYER Share tokens:", newBuyerShares);
        assertEq(newBuyerShares, 0);

        uint256 newBuyerAssetTokens = USDCMock(asset).balanceOf(BUYER);
        console.log("BUYER Asset tokens:", newBuyerAssetTokens);
        assertGt(newBuyerAssetTokens, buyerAssetTokens);

        console.log("-- test_RedeemPauseAndUnPause END --", "\n");
    }
}
