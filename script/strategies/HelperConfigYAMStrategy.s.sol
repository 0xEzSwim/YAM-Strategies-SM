// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract HelperConfigYAMStrategy {
    error HelperConfig__ConfigIsNotActive();

    struct NetworkConfig {
        address admin;
        address moderator;
        address asset;
        address market;
        address[] tokens;
    }

    NetworkConfig public activeNetworkConfig;

    modifier onlyActiveConfig() {
        if (activeNetworkConfig.asset == address(0)) {
            revert HelperConfig__ConfigIsNotActive();
        }
        _;
    }

    function getTokens() external view onlyActiveConfig returns (address[] memory) {
        address[] memory tokens = new address[](activeNetworkConfig.tokens.length);

        for (uint256 i = 0; i < activeNetworkConfig.tokens.length; i++) {
            tokens[i] = activeNetworkConfig.tokens[i];
        }

        return tokens;
    }

    function __HelperConfigYAMStrategy_init() internal {
        if (block.chainid == 100) {
            activeNetworkConfig = _getGnosisConfig();
        } else {
            // 31337 => Local chain (Anvil id)
            activeNetworkConfig = _getLocalConfig();
        }
    }

    function _getGnosisConfig() private view returns (NetworkConfig memory) {
        if (activeNetworkConfig.asset != address(0)) {
            return activeNetworkConfig;
        }

        return _createGnosisConfig();
    }

    function _createGnosisConfig() internal view virtual returns (NetworkConfig memory);

    function _getLocalConfig() private returns (NetworkConfig memory) {
        if (activeNetworkConfig.asset != address(0)) {
            return activeNetworkConfig;
        }

        return _createLocalConfig();
    }

    function _createLocalConfig() internal virtual returns (NetworkConfig memory);
}
