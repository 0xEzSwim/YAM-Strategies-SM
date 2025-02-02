// SPX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {RealTokenYamUpgradeableV3} from "../markets/RealTokenYamUpgradeableV3.sol";

contract YAMStrategyRealt is AccessControlUpgradeable, PausableUpgradeable, ERC4626Upgradeable, UUPSUpgradeable {
    using Math for uint256;

    struct HoldingDetails {
        uint256 _averageBuyingPrice;
        bool _isRealToken;
    }

    error YAMStrategy__NotUnderlyingAsset(address token);
    error YAMStrategy__NotRealToken(address token);
    error YAMStrategy__AmountToBuyIsTooLow();

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    address private _market;
    address[] private _holdingsLUT;
    mapping(address token => HoldingDetails) private _holdings;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address moderator_,
        string calldata name_,
        address asset_,
        address market_,
        address[] calldata tokens_
    ) public initializer {
        __AccessControl_init();
        __ERC20_init(
            string.concat("YAM Strategy RealToken ", ERC20(asset_).name(), " ", name_),
            string.concat("YS-REALT-", ERC20(asset_).symbol(), "-", name_)
        );
        __ERC4626_init(ERC20(asset_));
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(MODERATOR_ROLE, moderator_);

        _market = market_;
        _holdingsLUT = tokens_;
        for (uint8 i = 0; i < tokens_.length; i++) {
            _holdings[tokens_[i]] = HoldingDetails({_averageBuyingPrice: 0, _isRealToken: true});
        }
    }

    modifier isUnderlyingAsset(address token) {
        if (token != asset()) {
            revert YAMStrategy__NotUnderlyingAsset(token);
        }
        _;
    }

    modifier isRealToken(address token) {
        if (!isTypeRealToken(token)) {
            revert YAMStrategy__NotRealToken(token);
        }
        _;
    }

    function holdingsCount() external view returns (uint256) {
        return _holdingsLUT.length;
    }

    function holdingsAddress() external view returns (address[] memory) {
        return _holdingsLUT;
    }

    function tokenAverageBuyingPrice(address token) public view returns (uint256) {
        return _holdings[token]._averageBuyingPrice;
    }

    function tvl() public view returns (uint256) {
        uint256 totalValueInUnderlyingAsset = totalAssets();
        for (uint8 i = 0; i < _holdingsLUT.length; i++) {
            address token = _holdingsLUT[i];
            uint256 averageBuyingPrice = _holdings[token]._averageBuyingPrice;
            if (averageBuyingPrice == 0) {
                continue;
            }

            totalValueInUnderlyingAsset +=
                (averageBuyingPrice * ERC20(token).balanceOf(address(this))) / uint256(10) ** ERC20(token).decimals();
        }

        return totalValueInUnderlyingAsset;
    }

    function isTypeRealToken(address token) public view returns (bool) {
        return _holdings[token]._isRealToken;
    }

    function getVersion() external view returns (uint64) {
        return _getInitializedVersion();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _decimalsOffset() internal pure override returns (uint8) {
        return 18;
    }

    function getMarket() external view returns (address) {
        return _market;
    }

    function getRealToken(uint256 index) external view returns (address) {
        return _holdingsLUT[index];
    }

    function addRealToken(address token) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _holdingsLUT.push(token);
        _holdings[token] = HoldingDetails({_averageBuyingPrice: 0, _isRealToken: true});
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        return assets.mulDiv(totalSupply() + uint256(10) ** _decimalsOffset(), tvl() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        return shares.mulDiv(tvl() + 1, totalSupply() + uint256(10) ** _decimalsOffset(), rounding);
    }

    function _maxAmountToBuy(address tokenToReceive, uint256 price, uint256 amount) private view returns (uint256) {
        uint256 idealAmountToReceive = (totalAssets() * uint256(10) ** ERC20(tokenToReceive).decimals() / price);
        uint256 amountToReceive = idealAmountToReceive;
        int256 testMaxAmount = int256(amount) - int256(idealAmountToReceive); // same decimals
        if (testMaxAmount < 0) {
            amountToReceive = amount;
        }

        return amountToReceive;
    }

    function _maxUnderlyingAssetAmountToWithdraw(uint256 assets) private view returns (uint256) {
        uint256 amountToReceive = assets;
        int256 testMaxAmount = int256(totalAssets()) - int256(assets); // same decimals
        if (testMaxAmount < 0) {
            amountToReceive = totalAssets();
        }

        return amountToReceive;
    }

    function _calculateNewHoldingBuyingPrice(address token, uint256 price, uint256 amount)
        private
        view
        returns (uint256)
    {
        uint256 currentTokenBalance = ERC20(token).balanceOf(address(this));
        HoldingDetails memory holding = _holdings[token];
        return (holding._averageBuyingPrice * currentTokenBalance + price * amount) / (currentTokenBalance + amount);
    }

    function buyMaxRealTokenFromOffer(
        uint256 offerId,
        address offerToken,
        address buyerToken,
        uint256 price,
        uint256 amount
    )
        external
        whenNotPaused
        onlyRole(MODERATOR_ROLE)
        isUnderlyingAsset(buyerToken)
        isRealToken(offerToken)
        returns (uint256)
    {
        uint256 amountToBuy = _maxAmountToBuy(offerToken, price, amount);
        if ((amountToBuy * price) <= (uint256(10) ** ERC20(offerToken).decimals())) {
            revert YAMStrategy__AmountToBuyIsTooLow();
        }

        uint256 newAverageBuyingPrice = _calculateNewHoldingBuyingPrice(offerToken, price, amount);
        _holdings[offerToken] = HoldingDetails({_averageBuyingPrice: newAverageBuyingPrice, _isRealToken: true});

        uint256 assetAmountToSell = (amountToBuy * price) / uint256(10) ** ERC20(offerToken).decimals();
        ERC20(asset()).approve(address(_market), assetAmountToSell);
        RealTokenYamUpgradeableV3(_market).buy(offerId, price, amountToBuy);

        return amountToBuy;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        whenNotPaused
    {
        // If _asset is ERC-777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(ERC20(asset()), caller, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
        whenNotPaused
    {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        uint256 tvlBeforeBurn = tvl();
        uint256 assetToWithdraw = _maxUnderlyingAssetAmountToWithdraw(assets);
        uint256 remainingValueToWithdraw = assets - assetToWithdraw;
        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(owner, shares);
        SafeERC20.safeTransfer(ERC20(asset()), receiver, assetToWithdraw);

        // We might get issues on this check here
        if (remainingValueToWithdraw > 0) {
            for (uint8 i = 0; i < _holdingsLUT.length; i++) {
                address token = _holdingsLUT[i];
                if (isTypeRealToken(token)) {
                    uint256 tokenAssets = remainingValueToWithdraw.mulDiv(
                        ERC20(token).balanceOf(address(this)) + 1,
                        (tvlBeforeBurn - assetToWithdraw),
                        Math.Rounding.Floor
                    );
                    SafeERC20.safeTransfer(ERC20(token), receiver, tokenAssets);
                }
            }
        }

        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}
