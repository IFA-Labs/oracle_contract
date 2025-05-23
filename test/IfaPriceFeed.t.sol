// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Test.sol";
import "../src/IfaPriceFeedVerifier.sol";
import "../src/Interface/IIfaPriceFeed.sol";
import "./BaseTest.t.sol";
import {FixedPointMathLib} from "solady-0.1.12/src/utils/FixedPointMathLib.sol";

contract IfaPriceFeedTest is BaseTest {
    function setUp() public override {
        super.setUp();
        // Initialize with some asset prices
        initializeAssetPrices();
    }

    // ========== getAssetInfo Tests ==========

    function testGetAssetInfo_ValidAsset() public view {
        (IIfaPriceFeed.PriceFeed memory result,) = priceFeed.getAssetInfo(ASSET_BTC_INDEX);

        assertEq(result.price, priceBTC.price);
        assertEq(result.decimal, priceBTC.decimal);
        assertEq(result.lastUpdateTime, priceBTC.lastUpdateTime);
    }

    function testGetAssetInfo_InvalidAsset() public view {
        (, bool exist) = priceFeed.getAssetInfo(ASSET_NONEXISTENT);
        assertEq(exist, false);
    }

    // ========== getAssetsInfo Tests ==========

    function testGetAssetsInfo_ValidAssets() public view {
        bytes32[] memory assetIndexes = new bytes32[](2);
        assetIndexes[0] = ASSET_BTC_INDEX;
        assetIndexes[1] = ASSET_ETH_INDEX;

        (IIfaPriceFeed.PriceFeed[] memory results,) = priceFeed.getAssetsInfo(assetIndexes);

        assertEq(results.length, 2);
        assertEq(results[0].price, priceBTC.price);
        assertEq(results[1].price, priceETH.price);
    }

    function testGetAssetsInfo_OneInvalidAsset() public view {
        bytes32[] memory assetIndexes = new bytes32[](2);
        assetIndexes[0] = ASSET_BTC_INDEX;
        assetIndexes[1] = ASSET_NONEXISTENT;

        (, bool[] memory exists) = priceFeed.getAssetsInfo(assetIndexes);
        assertEq(exists[0], true);
        assertEq(exists[1], false);
    }

    function testGetAssetsInfo_EmptyArray() public view {
        bytes32[] memory assetIndexes = new bytes32[](0);

        (IIfaPriceFeed.PriceFeed[] memory results,) = priceFeed.getAssetsInfo(assetIndexes);
        assertEq(results.length, 0);
    }

    // ========== getPairbyId Tests ==========

    function testGetPairbyId_ForwardDirection() public view {
        IIfaPriceFeed.DerviedPair memory result =
            priceFeed.getPairbyId(ASSET_BTC_INDEX, ASSET_ETH_INDEX, IIfaPriceFeed.PairDirection.Forward);

        // BTC/ETH price should be 50000/3000 = 16.67 (with MAX_DECIMAL decimals)
        uint256 expectedPrice = (_scalePrice(priceBTC.price, priceBTC.decimal) * 10 ** MAX_DECIMAL)
            / _scalePrice(priceETH.price, priceETH.decimal);

        assertEq(result.derivedPrice, expectedPrice);
        assertEq(result.decimal, MAX_DECIMAL_NEGATIVE);
        assertEq(result.lastUpdateTime, min(priceBTC.lastUpdateTime, priceETH.lastUpdateTime));
    }

    function testGetPairbyId_BackwardDirection() public view {
        IIfaPriceFeed.DerviedPair memory result =
            priceFeed.getPairbyId(ASSET_BTC_INDEX, ASSET_ETH_INDEX, IIfaPriceFeed.PairDirection.Backward);

        // ETH/BTC price should be 3000/50000 = 0.06 (with MAX_DECIMAL decimals)
        uint256 expectedPrice = (_scalePrice(priceETH.price, priceETH.decimal) * 10 ** MAX_DECIMAL)
            / _scalePrice(priceBTC.price, priceBTC.decimal);

        assertEq(result.derivedPrice, expectedPrice);
        assertEq(result.decimal, MAX_DECIMAL_NEGATIVE);
        assertEq(result.lastUpdateTime, min(priceBTC.lastUpdateTime, priceETH.lastUpdateTime));
    }

    function testGetPairbyId_OneInvalidAsset() public {
        vm.expectRevert(abi.encodeWithSelector(IIfaPriceFeed.InvalidAssetIndex.selector, ASSET_NONEXISTENT));
        priceFeed.getPairbyId(ASSET_BTC_INDEX, ASSET_NONEXISTENT, IIfaPriceFeed.PairDirection.Forward);
    }

    // ========== getPairsbyIdForward Tests ==========

    function testGetPairsbyIdForward_ValidAssets() public view {
        bytes32[] memory assetIndexes0 = new bytes32[](2);
        bytes32[] memory assetIndexes1 = new bytes32[](2);

        assetIndexes0[0] = ASSET_BTC_INDEX;
        assetIndexes0[1] = ASSET_ETH_INDEX;

        assetIndexes1[0] = ASSET_ETH_INDEX;
        assetIndexes1[1] = ASSET_CNGN_INDEX;

        IIfaPriceFeed.DerviedPair[] memory results = priceFeed.getPairsbyIdForward(assetIndexes0, assetIndexes1);

        assertEq(results.length, 2);

        // First pair: BTC/ETH

        uint256 expectedPrice1 = (_scalePrice(priceBTC.price, priceBTC.decimal) * 10 ** MAX_DECIMAL)
            / _scalePrice(priceETH.price, priceETH.decimal);
        assertEq(results[0].derivedPrice, expectedPrice1);
        assertEq(results[0].derivedPrice, expectedPrice1);

        // Second pair: ETH/CNGN

        uint256 expectedPrice2 = (_scalePrice(priceETH.price, priceETH.decimal) * 10 ** MAX_DECIMAL)
            / _scalePrice(priceCNGN.price, priceCNGN.decimal);
        assertEq(results[1].derivedPrice, expectedPrice2);
        assertEq(results[1].derivedPrice, expectedPrice2);
    }

    function testGetPairsbyIdForward_InvalidLengths() public {
        bytes32[] memory assetIndexes0 = new bytes32[](2);
        bytes32[] memory assetIndexes1 = new bytes32[](1);

        assetIndexes0[0] = ASSET_BTC_INDEX;
        assetIndexes0[1] = ASSET_ETH_INDEX;

        assetIndexes1[0] = ASSET_CNGN_INDEX;

        vm.expectRevert(
            abi.encodeWithSelector(
                IIfaPriceFeed.InvalidAssetIndexLength.selector, assetIndexes0.length, assetIndexes0.length
            )
        );

        priceFeed.getPairsbyIdForward(assetIndexes0, assetIndexes1);
    }

    // ========== getPairsbyIdBackward Tests ==========

    function testGetPairsbyIdBackward_ValidAssets() public view {
        bytes32[] memory assetIndexes0 = new bytes32[](2);
        bytes32[] memory assetIndexes1 = new bytes32[](2);

        assetIndexes0[0] = ASSET_BTC_INDEX;
        assetIndexes0[1] = ASSET_ETH_INDEX;

        assetIndexes1[0] = ASSET_ETH_INDEX;
        assetIndexes1[1] = ASSET_CNGN_INDEX;

        IIfaPriceFeed.DerviedPair[] memory results = priceFeed.getPairsbyIdBackward(assetIndexes0, assetIndexes1);

        assertEq(results.length, 2);

        // First pair: ETH/BTC

        uint256 expectedPrice1 = (_scalePrice(priceETH.price, priceETH.decimal) * 10 ** MAX_DECIMAL)
            / _scalePrice(priceBTC.price, priceBTC.decimal);
        assertEq(results[0].derivedPrice, expectedPrice1);

        // Second pair: CNGN/ETH

        uint256 expectedPrice2 = (_scalePrice(priceCNGN.price, priceCNGN.decimal) * 10 ** MAX_DECIMAL)
            / _scalePrice(priceETH.price, priceETH.decimal);
        assertEq(results[1].derivedPrice, expectedPrice2);
    }

    function testGetPairsbyIdBackward_InvalidLengths() public {
        bytes32[] memory assetIndexes0 = new bytes32[](2);
        bytes32[] memory assetIndexes1 = new bytes32[](1);

        assetIndexes0[0] = ASSET_BTC_INDEX;
        assetIndexes0[1] = ASSET_ETH_INDEX;

        assetIndexes1[0] = ASSET_CNGN_INDEX;

        vm.expectRevert(
            abi.encodeWithSelector(
                IIfaPriceFeed.InvalidAssetIndexLength.selector, assetIndexes0.length, assetIndexes0.length
            )
        );

        priceFeed.getPairsbyIdBackward(assetIndexes0, assetIndexes1);
    }

    // ========== getPairsbyId Tests ==========

    function testGetPairsbyId_ValidAssets() public view {
        bytes32[] memory assetIndexes0 = new bytes32[](2);
        bytes32[] memory assetIndexes1 = new bytes32[](2);
        IIfaPriceFeed.PairDirection[] memory directions = new IIfaPriceFeed.PairDirection[](2);

        assetIndexes0[0] = ASSET_BTC_INDEX;
        assetIndexes0[1] = ASSET_ETH_INDEX;

        assetIndexes1[0] = ASSET_ETH_INDEX;
        assetIndexes1[1] = ASSET_CNGN_INDEX;

        directions[0] = IIfaPriceFeed.PairDirection.Forward;
        directions[1] = IIfaPriceFeed.PairDirection.Backward;

        IIfaPriceFeed.DerviedPair[] memory results = priceFeed.getPairsbyId(assetIndexes0, assetIndexes1, directions);

        assertEq(results.length, 2);

        // First pair: BTC/ETH (Forward)
        uint256 expectedPrice1 = (_scalePrice(priceBTC.price, priceBTC.decimal) * 10 ** MAX_DECIMAL)
            / _scalePrice(priceETH.price, priceETH.decimal);

        assertEq(results[0].derivedPrice, expectedPrice1);

        // Second pair: CNGN/ETH (Backward)

        uint256 expectedPrice2 = (_scalePrice(priceCNGN.price, priceCNGN.decimal) * 10 ** MAX_DECIMAL)
            / _scalePrice(priceETH.price, priceETH.decimal);
        assertEq(results[1].derivedPrice, expectedPrice2);
    }

    function testGetPairsbyId_InvalidLengths() public {
        bytes32[] memory assetIndexes0 = new bytes32[](2);
        bytes32[] memory assetIndexes1 = new bytes32[](2);
        IIfaPriceFeed.PairDirection[] memory directions = new IIfaPriceFeed.PairDirection[](1);

        assetIndexes0[0] = ASSET_BTC_INDEX;
        assetIndexes0[1] = ASSET_ETH_INDEX;

        assetIndexes1[0] = ASSET_ETH_INDEX;
        assetIndexes1[1] = ASSET_CNGN_INDEX;

        directions[0] = IIfaPriceFeed.PairDirection.Forward;

        vm.expectRevert(
            abi.encodeWithSelector(
                IIfaPriceFeed.InvalidAssetorDirectionIndexLength.selector,
                assetIndexes0.length,
                assetIndexes1.length,
                directions.length
            )
        );

        priceFeed.getPairsbyId(assetIndexes0, assetIndexes1, directions);
    }

    // ========== setAssetInfo Tests ==========

    function testSetAssetInfo_ValidVerifier() public {
        IIfaPriceFeed.PriceFeed memory newPrice = IIfaPriceFeed.PriceFeed({
            decimal: -18,
            lastUpdateTime: uint64(block.timestamp) + 100,
            price: 5200000000000 * 10e10 // $52,000 with 10 decimals
        });

        // Call from verifier directly to test
        vm.prank(address(verifier));
        priceFeed.setAssetInfo(ASSET_BTC_INDEX, newPrice);

        // Verify the asset was updated
        (IIfaPriceFeed.PriceFeed memory updatedPrice,) = priceFeed.getAssetInfo(ASSET_BTC_INDEX);

        assertEq(updatedPrice.decimal, newPrice.decimal);
        assertEq(updatedPrice.lastUpdateTime, newPrice.lastUpdateTime);
        assertEq(updatedPrice.price, newPrice.price);
    }

    function testSetAssetInfo_UnauthorizedCaller() public {
        IIfaPriceFeed.PriceFeed memory newPrice = IIfaPriceFeed.PriceFeed({
            decimal: -18,
            lastUpdateTime: uint64(block.timestamp) + 100,
            price: 5200000000000 * 10e10
        });

        // Try to call from non-verifier address
        vm.prank(user);
        vm.expectRevert(IIfaPriceFeed.NotVerifier.selector);
        priceFeed.setAssetInfo(ASSET_BTC_INDEX, newPrice);
    }

    // ========== setVerifier Tests ==========

    function testSetVerifier_Owner() public {
        vm.prank(owner);
        priceFeed.setVerifier(newVerifier);

        assertEq(priceFeed.IfaPriceFeedVerifier(), newVerifier);
    }

    function testSetVerifier_UnauthorizedUser() public {
        vm.prank(user);
        vm.expectRevert(); // Reverts due to onlyOwner modifier
        priceFeed.setVerifier(newVerifier);
    }

    function testSetVerifier_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIfaPriceFeed.InvalidVerifier.selector, address(0)));
        priceFeed.setVerifier(address(0));
    }

    // ========== Event Tests ==========

    function testSetAssetInfo_EventEmission() public {
        IIfaPriceFeed.PriceFeed memory newPrice = IIfaPriceFeed.PriceFeed({
            decimal: -18,
            lastUpdateTime: uint64(block.timestamp) + 100,
            price: 5200000000000 * 10e10
        });

        // Test for event emission
        vm.expectEmit(true, true, false, true);
        emit IIfaPriceFeed.AssetInfoSet(ASSET_BTC_INDEX, newPrice);

        vm.prank(address(verifier));
        priceFeed.setAssetInfo(ASSET_BTC_INDEX, newPrice);
    }

    function testSetVerifier_EventEmission() public {
        // Test for event emission
        vm.expectEmit(true, false, false, false);
        emit IIfaPriceFeed.VerifierSet(newVerifier);

        vm.prank(owner);
        priceFeed.setVerifier(newVerifier);
    }

    // ========== Helper Function ==========

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _scalePrice(int256 price, int8 decimal) internal pure returns (uint256) {
        uint256 scalePrice = uint256(price) * 10 ** (MAX_DECIMAL - uint8(-decimal));
        require(scalePrice > uint256(price));
        return scalePrice;
    }
}
