//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    uint8 number = 10;

    address s_user = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;  // decimals don't work in Solidity but thinks like 0.1 ether are allowed as shorthand for 1e17;
    uint256 constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        // like pytest, this is called at the start of every test
        number = 5;
        fundMe = new DeployFundMe().run();

        vm.deal(s_user, STARTING_BALANCE);  // give some credits to the user we just made up
    }

    function testDemo() view public {
        console.log(number);
        console.log("Hey hey hey!!");
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(s_user);  // the next transaction will be sent by s_user
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(s_user);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.prank(s_user);  // the next transaction will be sent by s_user
        fundMe.fund{value: SEND_VALUE}();

        vm.expectRevert();
        vm.prank(s_user);
        fundMe.withdraw();
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(s_user);  // the next transaction will be sent by s_user
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, s_user);
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