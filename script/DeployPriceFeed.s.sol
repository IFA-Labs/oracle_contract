//SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IfaPriceFeed} from "../src/IfaPriceFeed.sol";
import {IfaPriceFeedVerifier} from "src/IfaPriceFeedVerifier.sol";

contract DeployPriceFeed is Script {
    IfaPriceFeed ifaPriceFeed;
    IfaPriceFeedVerifier ifaPriceFeedVerifier;

    bytes32 constant SALT_IfaPriceFeed = keccak256("ifaPriceFeed");
    bytes32 constant SALT_ifaPriceFeedVerifier = keccak256("ifaPriceFeedVerifier");

    function run() public {
        vm.startBroadcast();
        console.log("Deploying from:", msg.sender);
        address owner = msg.sender;
        _depolyOracle(owner);

        vm.stopBroadcast();
    }

    function _depolyOracle(address owner) internal {
        ifaPriceFeed = new IfaPriceFeed{salt: SALT_IfaPriceFeed}(owner);
        console.log("IfaPriceFeed deployed at:", address(ifaPriceFeed));
        console.log("OWner from:", ifaPriceFeed.owner());
        ifaPriceFeedVerifier = new IfaPriceFeedVerifier{salt: SALT_IfaPriceFeed}(
            address(0xCCB3f2CC8592126a80B91B53eE4d7332F54d980d), address(ifaPriceFeed), owner
        ); //@note change the relayer address when deploying to testnet/mainnet
        console.log("IfaPriceFeedVerifier deployed at:", address(ifaPriceFeedVerifier));
        ifaPriceFeed.setVerifier(address(ifaPriceFeedVerifier));
    }
}
