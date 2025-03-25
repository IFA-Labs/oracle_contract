// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

interface IIfaPriceFeed {
    enum PairDirection {
        Forward, // asset0/asset1
        Backward // asset1/asset0

    }

    error InvalidAssetIndex(uint64 _assetIndex);

    struct PriceFeed {
        uint256 decimals;
        uint256 lastUpdateTime;
        uint256 price;
        uint256 roundId;
    }

    function getAssetbyTokenAddress() external;
    function getAssetsbyTokenAddress() external;
    function getAssetInfo(uint64 _assetIndex) external;
    function getAssetsInfo(uint64[] memory _assetIndexes) external;
    function UpdatePriceFeed() external;
    function getPairbyIds(uint64 _assetIndex0, uint64 _assetIndex1, PairDirection _direction) external;
    function getPairsbyIds(uint64[] memory _assetIndexes0, uint64[] memory _assetsIndexes1, PairDirection _direction)
        external;
}
