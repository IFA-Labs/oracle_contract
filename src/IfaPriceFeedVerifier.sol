// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import {IIfaPriceFeed} from "./Interface/IIfaPriceFeed.sol";
import {Ownable} from "solady-0.1.12/src/auth/Ownable.sol";

contract IfaPriceFeedVerifier is Ownable {
    error InvalidRelayerNode(address _address);
    error OnlyRelayerNode(address _caller);
    error InvalidAssetIndexorPriceLength();

    address public relayerNode;
    IIfaPriceFeed public immutable IfaPriceFeed;

    constructor(address _relayerNode, address _IIfaPriceFeed, address _owner) {
        _initializeOwner(_owner); // setting owner of contract
        relayerNode = _relayerNode;
        IfaPriceFeed = IIfaPriceFeed(_IIfaPriceFeed);
    }

    modifier onlyRelayerNode() {
        require(msg.sender == relayerNode, OnlyRelayerNode(msg.sender));
        _;
    }

    function submitPriceFeed(uint64[] calldata _assetindex, IIfaPriceFeed.PriceFeed[] calldata _prices)
        external
        onlyRelayerNode
    {
        require(_assetindex.length == _prices.length, InvalidAssetIndexorPriceLength());

        for (uint256 i = 0; i < _assetindex.length; i++) {
            uint64 pair = _assetindex[i];
            IIfaPriceFeed.PriceFeed calldata currentPriceFeed = _prices[i];
            uint256 currenttimestamp = currentPriceFeed.lastUpdateTime;
            (IIfaPriceFeed.PriceFeed memory prevPriceFeed,) = IfaPriceFeed.getAssetInfo(pair);
            if (prevPriceFeed.lastUpdateTime > currenttimestamp) {
                continue;
            }

            IfaPriceFeed.setAssetInfo(pair, currentPriceFeed);
        }
    }

    function setRelayerNode(address _relayerNode) external onlyOwner {
        require(_relayerNode != address(0), InvalidRelayerNode(_relayerNode));
        relayerNode = _relayerNode;
    }
    ///@dev Override to return true to prevent double-initialization.

    function _guardInitializeOwner() internal pure override returns (bool guard) {
        guard = true;
    }
}
