// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Test.sol";
import "../src/IfaPriceFeed.sol";
import "../src/IfaPriceFeedVerifier.sol";
import "../src/Interface/IIfaPriceFeed.sol";

contract BaseTest is Test {
    // Constants
    uint64 constant ASSET_BTC_INDEX = 1;
    uint64 constant ASSET_ETH_INDEX = 2;
    uint64 constant ASSET_CNGN_INDEX = 3;
    uint64 constant ASSET_NONEXISTENT = 999;
    uint8 constant MAX_DECIMAL = 18;

    // Contracts
    IfaPriceFeed public priceFeed;
    IfaPriceFeedVerifier public verifier;

    // Actors
    address public owner = address(0x1);
    address public relayerNode = address(0x2);
    address public newRelayerNode = address(0x3);
    address public newVerifier = address(0x4);
    address public user = address(0x5);

    // Sample price data
    IIfaPriceFeed.PriceFeed priceBTC = IIfaPriceFeed.PriceFeed({
        decimal: 8,
        lastUpdateTime: block.timestamp,
        price: 5000000000000, // $50,000 with 8 decimals
        roundId: 1
    });

    IIfaPriceFeed.PriceFeed priceETH = IIfaPriceFeed.PriceFeed({
        decimal: 8,
        lastUpdateTime: block.timestamp,
        price: 300000000000, // $3,000 with 8 decimals
        roundId: 2
    });

    IIfaPriceFeed.PriceFeed priceCNGN = IIfaPriceFeed.PriceFeed({
        decimal: 8,
        lastUpdateTime: block.timestamp,
        price: 150000, // $0.0015 with 8 decimals
        roundId: 3
    });

    function setUp() public virtual {
        vm.startPrank(owner);

        // Deploy contracts
        priceFeed = new IfaPriceFeed();
        verifier = new IfaPriceFeedVerifier(relayerNode, address(priceFeed));

        // Set verifier in price feed
        priceFeed.setVerifier(address(verifier));

        vm.stopPrank();
    }

    // Helper function to initialize asset prices
    function initializeAssetPrices() internal {
        uint64[] memory assetIndexes = new uint64[](3);
        IIfaPriceFeed.PriceFeed[] memory prices = new IIfaPriceFeed.PriceFeed[](3);

        assetIndexes[0] = ASSET_BTC_INDEX;
        assetIndexes[1] = ASSET_ETH_INDEX;
        assetIndexes[2] = ASSET_CNGN_INDEX;

        prices[0] = priceBTC;
        prices[1] = priceETH;
        prices[2] = priceCNGN;

        vm.prank(relayerNode);
        verifier.submitPriceFeed(assetIndexes, prices);
    }
}
