// SPX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {CleanSatMining} from "./market/CleanSatMining.sol";

contract YAMStrategyCSM is AccessControlUpgradeable, PausableUpgradeable, ERC4626Upgradeable, UUPSUpgradeable {
    using Math for uint256;

    error CSMStrategy__NotUnderlyingAsset(address token);
    error CSMStrategy__NotCSM(address token);
    error CSMStrategy__AmountToBuyIsToLow();

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    address private csmMarket;
    address[] private csmTokens;
    mapping(address token => bool isTypeCSM) private isTypeCSM_token;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _moderator,
        string calldata _name,
        address _asset,
        address _csmMarket,
        address[] calldata _csmTokens
    ) public initializer {
        __AccessControl_init();
        __ERC20_init(
            string.concat("YAM Strategy CSM ", ERC20(_asset).name(), " ", _name),
            string.concat("YS-CSM-", ERC20(_asset).symbol(), "-", _name)
        );
        __ERC4626_init(ERC20(_asset));
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(MODERATOR_ROLE, _moderator);

        csmMarket = _csmMarket;
        csmTokens = _csmTokens;
        for (uint8 i = 0; i < _csmTokens.length; i++) {
            isTypeCSM_token[_csmTokens[i]] = true;
        }
    }

    modifier isUnderlyingAsset(address token) {
        if (token != asset()) {
            revert CSMStrategy__NotUnderlyingAsset(token);
        }
        _;
    }

    modifier isCSM(address token) {
        if (!isCSMToken(token)) {
            revert CSMStrategy__NotCSM(token);
        }
        _;
    }

    function isCSMToken(address token) public view returns (bool) {
        return isTypeCSM_token[token];
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

    function getCsmMarket() external view returns (address) {
        return csmMarket;
    }

    function getCsmToken(uint256 index) external view returns (address) {
        return csmTokens[index];
    }

    function addCsmToken(address token) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        csmTokens.push(token);
        isTypeCSM_token[token] = true;
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

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        uint256 oldTotalSypply = totalSupply();
        _burn(owner, shares);
        SafeERC20.safeTransfer(ERC20(asset()), receiver, assets);
        for (uint8 i = 0; i < csmTokens.length; i++) {
            address token = csmTokens[i];
            if (isCSMToken(token)) {
                uint256 csmAssets = shares.mulDiv(
                    ERC20(token).balanceOf(address(this)) + 1,
                    oldTotalSypply + 10 ** (decimals() - ERC20(token).decimals()),
                    Math.Rounding.Floor
                );
                SafeERC20.safeTransfer(ERC20(token), receiver, csmAssets);
            }
        }

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _maxAmountToReceive(address tokenToReceive, uint256 price, uint256 amount)
        private
        view
        returns (uint256)
    {
        uint256 idealAmountToReceive = (totalAssets() * uint256(10) ** ERC20(tokenToReceive).decimals() / price);
        uint256 amountToReceive = idealAmountToReceive;
        int256 testMaxAmount = int256(amount) - int256(idealAmountToReceive); // same decimals
        if (testMaxAmount < 0) {
            amountToReceive = amount;
        }

        return amountToReceive;
    }

    function buyMaxCSMTokenFromOffer(
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
        isCSM(offerToken)
        returns (uint256)
    {
        uint256 amountToBuy = _maxAmountToReceive(offerToken, price, amount);
        if ((amountToBuy * price) <= (uint256(10) ** ERC20(offerToken).decimals())) {
            revert CSMStrategy__AmountToBuyIsToLow();
        }

        uint256 priceToSend = (amountToBuy * price) / uint256(10) ** ERC20(offerToken).decimals();
        ERC20(asset()).approve(address(csmMarket), priceToSend);
        CleanSatMining(csmMarket).buy(offerId, price, amountToBuy);

        return amountToBuy;
    }
}
