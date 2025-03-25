// SPDX-License-Identifer: MIT

pragma solidity 0.8.29;

import {IIfaPriceFeed} from "./Interface/IIfaPriceFeed.sol";

/// @title IFALABS Oracle Price Feed Contract
/// @author IFALABS
/// @notice This contract is used for to storing the exchange rate of Assets
/// @dev  what is an asset? A asset is a token price  with respect to USD  e.g CNGN/USD
abstract contract IfaPriceFeed is IIfaPriceFeed {
    /// @notice Mapping of asset index to its price information
    mapping(uint64 assetIndex => PriceFeed assetInfo) _assetInfo;

    /// @notice Returns the price information of an asset
    /// @param _assetIndex The index of the asset
    /// returns The price information of the asset
    function _getAssetInfo(uint64 _assetIndex) internal view returns (PriceFeed memory assetInfo) {
        require(_assetInfo[_assetIndex].lastUpdateTime > 0, InvalidAssetIndex(_assetIndex));
        return _assetInfo[_assetIndex];
    }

    /// @notice Get the price information of an asset revert if the asset index is invalid
    /// @param _assetIndex The index of the asset
    /// returns The price information of the asset
    function getAssetInfo(uint64 _assetIndex) external view returns (PriceFeed memory assetInfo) {
        return _getAssetInfo(_assetIndex);
    }

    /// @notice  Get the price information of an array of assets revert if any asset index is invalid
    /// @param _assetIndexes The array of asset indexes
    /// returns The price information of the assets
    function getAssetsInfo(uint64[] memory _assetIndexes) external view returns (PriceFeed[] memory assetsInfo) {
        for (uint256 i = 0; i < _assetIndexes.length; i++) {
            assetsInfo[i] = _getAssetInfo(_assetIndexes[i]);
        }
    }
}
