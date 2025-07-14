//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {FundFundMe, WithdrawFundMe} from "../../script/Interactions.s.sol";

contract FundMeIntegrationTest is Test {
    FundMe public fundMe;

    address s_user = makeAddr("user");

    uint256 public constant SEND_VALUE = 0.1 ether;  // decimals don't work in Solidity but thinks like 0.1 ether are allowed as shorthand for 1e17;
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant GAS_PRICE = 1;

    modifier funded() {
        vm.prank(s_user);  // the next transaction will be sent by s_user
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function setUp() external {
        (fundMe,) = new DeployFundMe().run();

        vm.deal(s_user, STARTING_BALANCE);  // give some credits to the user we just made up
    }

    function testUserCanFundIntegration() public funded {
        FundFundMe fundFundMe = new FundFundMe();
        fundFundMe.fundFundMe(address(fundMe));

        address funder = fundMe.getFunder(0);
        assertEq(funder, s_user);

        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMe));

        assertEq(address(fundMe).balance, 0);
    }
}