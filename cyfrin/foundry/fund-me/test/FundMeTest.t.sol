//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    uint8 number = 10;

    function setUp() external {
        number = 5;
        fundMe = new DeployFundMe().run();
    }

    function testDemo() view public {
        console.log(number);
        console.log("Hey hey hey!!");
    }

    function testMinimumUsdIsFive() view public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }
    
    function testOwnerIsMsgSender() view public {
        // Why use address(this) instead of msg.sender?
        // Because msg.sender is "our" address, i.e.: the address of whoever is calling FundMeTest.
        // address(this) is the address of FundMeTest.
        // FundMeTest is the owner of FundMe, not whoever ran the tests.
        assertEq(fundMe.i_owner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() view public {
        assertEq(fundMe.getVersion(), 4);
    }
}