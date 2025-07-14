// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract FundMeTest is ZkSyncChainChecker, CodeConstants, StdCheats, Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;

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
        if (isZkSyncChain()) {
            MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
            fundMe = new FundMe(address(mockPriceFeed));
        } else {
            DeployFundMe deployer = new DeployFundMe();
            (fundMe, helperConfig) = deployer.deployFundMe();
        }

        vm.deal(s_user, STARTING_BALANCE);
    }

    function testPriceFeedSetCorrectly() public skipZkSync {
        address retreivedPriceFeed = address(fundMe.getPriceFeed());
        // (address expectedPriceFeed) = helperConfig.activeNetworkConfig();
        address expectedPriceFeed = helperConfig.getConfigByChainId(block.chainid).priceFeed;

        assertEq(retreivedPriceFeed, expectedPriceFeed);
    }

    function testFundFailsWithoutEnoughEth() public skipZkSync {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public skipZkSync {
        vm.prank(s_user);  // the next transaction will be sent by s_user
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(s_user);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testOnlyOwnerCanWithdraw() public funded skipZkSync {
        vm.expectRevert();
        vm.prank(s_user);
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded skipZkSync {
        // Arrange
        address owner = fundMe.getOwner();
        uint256 startingOwnerBalance = owner.balance;
        uint256 startingFunderAmount = fundMe.getAddressToAmountFunded(s_user);

        // Act
        vm.prank(owner);
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = owner.balance;
        uint256 endingFunderAmount = fundMe.getAddressToAmountFunded(s_user);

        assertNotEq(startingFunderAmount, 0);
        assertEq(startingFunderAmount + startingOwnerBalance, endingOwnerBalance);
        assertEq(endingFunderAmount, 0);
        
        // Funders should now be empty
        vm.expectRevert();
        fundMe.getFunder(0);
    }

    // NB: this test fails with --fork-url $SEPOLIA_RPC_URL
    function testWithdrawFromMultipleFunders() public funded skipZkSync {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);  // hoax = vm.prank + vm.deal
            fundMe.fund{value: SEND_VALUE}();
        }

        address owner = fundMe.getOwner();
        uint256 startingOwnerBalance = owner.balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(owner);
        fundMe.withdraw();
        vm.stopPrank();
        
        // Assert
        uint256 endingOwnerBalance = owner.balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertNotEq(startingFundMeBalance, 0);
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);
        assertEq(endingFundMeBalance, 0);
        
        // Funders should now be empty
        vm.expectRevert();
        fundMe.getFunder(0);
    }

    function testAddsFunderToArrayOfFunders() public funded skipZkSync {
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
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() view public {
        assertEq(fundMe.getVersion(), 4);
    }
}
