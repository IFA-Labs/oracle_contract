// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "../src/Interface/IIfaPriceFeed.sol";
import "./BaseTest.t.sol";

contract IfaPriceFeedVerifierTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    // ========== submitPriceFeed Tests ==========

    function testSubmitPriceFeed_AuthorizedRelayer() public {
        uint64[] memory assetIndexes = new uint64[](1);
        IIfaPriceFeed.PriceFeed[] memory prices = new IIfaPriceFeed.PriceFeed[](1);

        assetIndexes[0] = ASSET_BTC_INDEX;
        prices[0] = priceBTC;

        vm.prank(relayerNode);
        verifier.submitPriceFeed(assetIndexes, prices);

        // Verify the asset was updated in the priceFeed contract
        (IIfaPriceFeed.PriceFeed memory updatedPrice,) = priceFeed.getAssetInfo(ASSET_BTC_INDEX);

        assertEq(updatedPrice.decimal, priceBTC.decimal);
        assertEq(updatedPrice.lastUpdateTime, priceBTC.lastUpdateTime);
        assertEq(updatedPrice.price, priceBTC.price);
        assertEq(updatedPrice.roundId, priceBTC.roundId);
    }

    function testSubmitPriceFeed_AuthorizedRelayer_StaleData() public {
        IIfaPriceFeed.PriceFeed memory _priceBTC = IIfaPriceFeed.PriceFeed({
            decimal: 8,
            lastUpdateTime: 36000,
            price: 5000000000000, // $50,000 with 8 decimals
            roundId: 1
        });
        uint64[] memory assetIndexes = new uint64[](1);

        IIfaPriceFeed.PriceFeed[] memory prices = new IIfaPriceFeed.PriceFeed[](1);

        assetIndexes[0] = ASSET_BTC_INDEX;
        prices[0] = _priceBTC;

        vm.prank(relayerNode);
        verifier.submitPriceFeed(assetIndexes, prices);

        IIfaPriceFeed.PriceFeed memory priceBTCStale = IIfaPriceFeed.PriceFeed({
            decimal: 8,
            lastUpdateTime: 1,
            price: 4900000000000, // $49 ,000 with 8 decimals
            roundId: 1
        });
        uint64[] memory assetIndexesStaled = new uint64[](1);
        IIfaPriceFeed.PriceFeed[] memory pricesStaled = new IIfaPriceFeed.PriceFeed[](1);

        assetIndexesStaled[0] = ASSET_BTC_INDEX;

        pricesStaled[0] = priceBTCStale;

        // Verify the asset was updated in the priceFeed contract
        (IIfaPriceFeed.PriceFeed memory updatedPrice,) = priceFeed.getAssetInfo(ASSET_BTC_INDEX);

        assertEq(updatedPrice.decimal, _priceBTC.decimal);
        assertEq(updatedPrice.lastUpdateTime, _priceBTC.lastUpdateTime);
        assertEq(updatedPrice.price, _priceBTC.price);
        assertEq(updatedPrice.roundId, _priceBTC.roundId);
    }

    function testSubmitPriceFeed_UnauthorizedCaller() public {
        uint64[] memory assetIndexes = new uint64[](1);
        IIfaPriceFeed.PriceFeed[] memory prices = new IIfaPriceFeed.PriceFeed[](1);

        assetIndexes[0] = ASSET_BTC_INDEX;
        prices[0] = priceBTC;

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OnlyRelayerNode(address)", user));
        verifier.submitPriceFeed(assetIndexes, prices);
    }

    function testSubmitPriceFeed_InvalidLengths() public {
        uint64[] memory assetIndexes = new uint64[](2);
        IIfaPriceFeed.PriceFeed[] memory prices = new IIfaPriceFeed.PriceFeed[](1);

        assetIndexes[0] = ASSET_BTC_INDEX;
        assetIndexes[1] = ASSET_ETH_INDEX;
        prices[0] = priceBTC;

        vm.prank(relayerNode);
        vm.expectRevert(abi.encodeWithSignature("InvalidAssetIndexorPriceLength()"));
        verifier.submitPriceFeed(assetIndexes, prices);
    }

    // ========== setRelayerNode Tests ==========

    function testsetRelayerNode_Owner() public {
        vm.prank(owner);
        verifier.setRelayerNode(newVerifier);

        assertEq(verifier.relayerNode(), newVerifier);
    }

    function testsetRelayerNode_UnauthorizedUser() public {
        vm.prank(user);
        vm.expectRevert(); // Reverts due to onlyOwner modifier
        verifier.setRelayerNode(newVerifier);
    }

    function testsetRelayerNode_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("InvalidRelayerNode(address)", address(0)));
        verifier.setRelayerNode(address(0));
    }
}
