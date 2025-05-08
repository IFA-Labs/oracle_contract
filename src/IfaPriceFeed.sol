// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import {IIfaPriceFeed} from "./Interface/IIfaPriceFeed.sol";
import {Ownable} from "solady-0.1.12/src/auth/Ownable.sol";
import {FixedPointMathLib} from "solady-0.1.12/src/utils/FixedPointMathLib.sol";
/// @title IFALABS Oracle Price Feed Contract
/// @author IFALABS
/// @notice This contract is used for to storing the exchange rate of Assets  and calculating the price of Paira
/// @dev  what is an asset? A asset is a token price  with respect to USD  e.g CNGN/USD
/// @dev  what is a pair? A pair is a combination of two asset with respect to each out  e.g CNGN/BTC

contract IfaPriceFeed is IIfaPriceFeed, Ownable {
    uint8 constant MAX_DECIMAL = 30;
    int8 constant MAX_DECIMAL_NEGATIVE = -30;
    uint256 constant MAX_INT256 = 57896044618658097711785492504343953926634992332820282019728792003956564819967;

    address public IfaPriceFeedVerifier;
    /// @notice Mapping of asset index to its price information
    mapping(bytes32 assetIndex => PriceFeed assetInfo) _assetInfo;

    constructor(address _owner) {
        _initializeOwner(_owner); // setting owner of contract
    }

    modifier onlyVerifier() {
        if (msg.sender != IfaPriceFeedVerifier) {
            revert NotVerifier();
        }
        _;
    }

    /// @notice Get the price information of an asset revert if the asset index is invalid
    /// @param _assetIndex The index of the asset
    /// @return assetInfo The price information of the asset
    function getAssetInfo(bytes32 _assetIndex) external view returns (PriceFeed memory assetInfo, bool exist) {
        return _getAssetInfo(_assetIndex);
    }

    /// @notice  Get the price information of an array of assets revert if any asset index is invalid
    /// @param _assetIndexes The array of asset indexes
    /// @return assetsInfo The price information of the assets
    function getAssetsInfo(bytes32[] calldata _assetIndexes)
        external
        view
        returns (PriceFeed[] memory, bool[] memory)
    {
        uint256 arrayLength = _assetIndexes.length;
        PriceFeed[] memory assetsInfo = new PriceFeed[](arrayLength);
        bool[] memory exists = new bool[](arrayLength);
        for (uint256 i = 0; i < arrayLength; i++) {
            (assetsInfo[i], exists[i]) = _getAssetInfo(_assetIndexes[i]);
        }
        return (assetsInfo, exists);
    }
    /// @notice Retrieves pair information for a given asset pair and direction.
    /// @param _assetIndex0 Index of the first asset.
    /// @param _assetIndex1 Index of the second asset.
    /// @param _direction Direction of the pair (Forward or Backward).
    /// @return pairInfo The derived pair information.

    function getPairbyId(bytes32 _assetIndex0, bytes32 _assetIndex1, PairDirection _direction)
        external
        view
        returns (DerviedPair memory pairInfo)
    {
        return _getPairInfo(_assetIndex0, _assetIndex1, _direction);
    }

    /// @notice Retrieves pair information for multiple asset pairs in the forward direction.
    /// @param _assetIndexes0 Array of indexes for the first assets in pairs.
    /// @param _assetsIndexes1 Array of indexes for the second assets in pairs.
    /// @return pairsInfo Array of derived pair information.
    function getPairsbyIdForward(bytes32[] calldata _assetIndexes0, bytes32[] calldata _assetsIndexes1)
        external
        view
        returns (DerviedPair[] memory)
    {
        uint256 arrayLength = _assetIndexes0.length;
        DerviedPair[] memory pairsInfo = new DerviedPair[](arrayLength);
        // sayh you have asset0 =  CNGN/USD  and  asset1 =  BTC/USD   the function will give you  CNGN/BTC
        require(
            _assetIndexes0.length == _assetsIndexes1.length,
            InvalidAssetIndexLength(_assetIndexes0.length, _assetIndexes0.length)
        );
        for (uint256 i = 0; i < arrayLength; i++) {
            pairsInfo[i] = _getPairInfo(_assetIndexes0[i], _assetsIndexes1[i], PairDirection.Forward);
        }
        return pairsInfo;
    }

    /// @notice Retrieves pair information for multiple asset pairs in the backward direction.
    /// @param _assetIndexes0 Array of indexes for the first assets in pairs.
    /// @param _assetsIndexes1 Array of indexes for the second assets in pairs.
    /// @return pairsInfo Array of derived pair information.

    function getPairsbyIdBackward(bytes32[] calldata _assetIndexes0, bytes32[] calldata _assetsIndexes1)
        external
        view
        returns (DerviedPair[] memory)
    {
        uint256 arrayLength = _assetIndexes0.length;
        DerviedPair[] memory pairsInfo = new DerviedPair[](arrayLength);
        // say you have asset0 =  CNGN/USD  and  asset1 =  BTC/USD   the function will give you BTC/CNGN
        require(
            _assetIndexes0.length == _assetsIndexes1.length,
            InvalidAssetIndexLength(_assetIndexes0.length, _assetIndexes0.length)
        );
        for (uint256 i = 0; i < arrayLength; i++) {
            pairsInfo[i] = _getPairInfo(_assetIndexes0[i], _assetsIndexes1[i], PairDirection.Backward);
        }
        return pairsInfo;
    }

    /// @notice Retrieves pair information for multiple asset pairs with specified directions.
    /// @param _assetIndexes0 Array of indexes for the first assets in pairs.
    /// @param _assetsIndexes1 Array of indexes for the second assets in pairs.
    /// @param _direction Array of directions for each pair (Forward or Backward).
    /// @return pairsInfo Array of derived pair information.
    function getPairsbyId(
        bytes32[] calldata _assetIndexes0,
        bytes32[] calldata _assetsIndexes1,
        PairDirection[] calldata _direction
    ) external view returns (DerviedPair[] memory) {
        uint256 arrayLength = _assetIndexes0.length;
        DerviedPair[] memory pairsInfo = new DerviedPair[](arrayLength);

        require(
            _assetIndexes0.length == _assetsIndexes1.length && _assetIndexes0.length == _direction.length,
            InvalidAssetorDirectionIndexLength(_assetIndexes0.length, _assetIndexes0.length, _direction.length)
        );
        for (uint256 i = 0; i < arrayLength; i++) {
            pairsInfo[i] = _getPairInfo(_assetIndexes0[i], _assetsIndexes1[i], _direction[i]);
        }
        return pairsInfo;
    }

    /// @notice Internal function to compute derived pair information for two assets.
    /// @param _assetIndex0 Index of the first asset.
    /// @param _assetIndex1 Index of the second asset.
    /// @param _direction Direction of the pair (Forward or Backward).
    /// @return pairInfo The derived pair information.
    function _getPairInfo(bytes32 _assetIndex0, bytes32 _assetIndex1, PairDirection _direction)
        internal
        view
        returns (DerviedPair memory pairInfo)
    {
        (PriceFeed memory _assetInfo0, bool exist0) = _getAssetInfo(_assetIndex0);
        (PriceFeed memory _assetInfo1, bool exist1) = _getAssetInfo(_assetIndex1);
        if (!exist0) revert InvalidAssetIndex(_assetIndex0);
        if (!exist1) revert InvalidAssetIndex(_assetIndex1);
        int256 _price0 = _assetInfo0.price;
        int256 _price1 = _assetInfo1.price;
        int8 _decimal0 = _assetInfo0.decimal;
        int8 _decimal1 = _assetInfo1.decimal;

        uint256 derivedPrice;
        int256 roundDifference;
        {
            int256 _roundId0 = _assetInfo0.roundId;
            int256 _roundId1 = _assetInfo1.roundId;
            if (_roundId0 >= _roundId1) {
                roundDifference = int256(_roundId0) - int256(_roundId1);
            } else {
                roundDifference = int256(_roundId1) - int256(_roundId0);
            }
        }
        if (_direction == PairDirection.Forward) {
            // (asset0/usd) / (asset1/usd) = asset0 / asset1
            // Scaling asset decimals to MAX_DECIMAL(30) for precision
            // derivedPrice = (_scalePrice(_price0, _decimal0) * 10 ** MAX_DECIMAL) / _scalePrice(_price1, _decimal1);
            derivedPrice = FixedPointMathLib.mulDiv(
                _scalePrice(_price0, _decimal0), 10 ** MAX_DECIMAL, _scalePrice(_price1, _decimal1)
            );
        } else {
            // (asset1/usd) / (asset0/usd) = asset1 /asset0
            //derivedPrice = (_scalePrice(_price1, _decimal1) * 10 ** MAX_DECIMAL) / _scalePrice(_price0, _decimal0);
            derivedPrice = FixedPointMathLib.mulDiv(
                _scalePrice(_price1, _decimal1), 10 ** MAX_DECIMAL, _scalePrice(_price0, _decimal0)
            );
        }

        return DerviedPair({
            decimal: MAX_DECIMAL_NEGATIVE,
            lastUpdateTime: _min(_assetInfo0.lastUpdateTime, _assetInfo1.lastUpdateTime),
            derivedPrice: derivedPrice,
            roundDifference: roundDifference
        });
    }

    /// @notice Sets the price information of an asset (to be called by the verifier contract)
    /// @param _assetIndex The index of the asset
    /// @param assetInfo The price information of the asset
    function setAssetInfo(bytes32 _assetIndex, PriceFeed calldata assetInfo) external onlyVerifier {
        _setAssetInfo(_assetIndex, assetInfo);
    }
    /// @notice Sets the verifier for the price feed
    /// @param _verifier The address of the verifier

    function setVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), InvalidVerifier(_verifier));
        IfaPriceFeedVerifier = _verifier;
        emit VerifierSet(_verifier);
    }
    /// @notice Returns the price information of an asset with revert if the asset index is invalid
    /// @param _assetIndex The index of the asset
    /// @return assetInfo The price information of the asset

    function _getAssetInfo(bytes32 _assetIndex) internal view returns (PriceFeed memory assetInfo, bool exist) {
        //require(_assetInfo[_assetIndex].lastUpdateTime > 0, InvalidAssetIndex(_assetIndex));
        if (_assetInfo[_assetIndex].lastUpdateTime > 0) {
            exist = true;
            return (_assetInfo[_assetIndex], exist);
        } else {
            exist = false;
            return (_assetInfo[_assetIndex], exist);
        }
    }

    /// @notice Sets the price information of an asset
    /// @param _assetIndex The index of the asset
    /// @param assetInfo The price information of the asset
    function _setAssetInfo(bytes32 _assetIndex, PriceFeed calldata assetInfo) internal {
        // price verification will be done on the  Verifier contract
        _assetInfo[_assetIndex] = assetInfo;
        emit AssetInfoSet(_assetIndex, assetInfo);
    }
    /// @notice Returns the minimum of two numbers
    /// @param a The first number
    /// @param b The second number
    /// @return minimum The minimum of a and b

    function _min(uint256 a, uint256 b) internal pure returns (uint256 minimum) {
        if (a < b) {
            minimum = a;
        } else {
            minimum = b;
        }
    }

    /// @notice Helps to scale the price of a pair id to 18 decimal places
    /// @param price the price of the pair ID
    /// @param decimal number of decimals that the pair info supports
    /// @return the scaled prices of the pair

    function _scalePrice(int256 price, int8 decimal) internal pure returns (uint256) {
        uint256 scalePrice = uint256(price) * 10 ** (MAX_DECIMAL - uint8(-decimal));
        require(scalePrice <= MAX_INT256);
        require(scalePrice > uint256(price));
        return scalePrice;
    }
    ///@dev Override to return true to prevent double-initialization.

    function _guardInitializeOwner() internal pure override returns (bool guard) {
        guard = true;
    }
}
