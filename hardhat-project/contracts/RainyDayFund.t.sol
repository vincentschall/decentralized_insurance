// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RainyDayFund} from "../contracts/RainyDayFund.sol";
import {MockUSDC} from "../contracts/MockUSDC.sol";
import {Test} from "forge-std/Test.sol";

contract RainyDayFundTest is Test {
    RainyDayFund rainyDayFund;
    MockUSDC mockUSDC;
    
    address owner;
    address farmer1;
    address investor1;
    
    function setUp() public {
        owner = address(this);
        farmer1 = address(0x1);
        investor1 = address(0x2);
        
        // Deploy MockUSDC first
        mockUSDC = new MockUSDC();
        
        // Deploy RainyDayFund with MockUSDC address
        rainyDayFund = new RainyDayFund(address(mockUSDC));
        
        // Give tokens to test addresses
        mockUSDC.mint(farmer1, 1000 * 10**6); // 1000 USDC
        mockUSDC.mint(investor1, 5000 * 10**6); // 5000 USDC
    }
    
    function test_InitialState() public view {
        require(rainyDayFund.owner() == owner, "Owner should be deployer");
        require(rainyDayFund.riskPoolBalance() == 0, "Initial risk pool should be 0");
        require(rainyDayFund.getTotalPolicies() == 0, "Initial policies should be 0");
    }
    
    function test_BuyBasicPolicy() public {
        // Setup: farmer1 approves and buys basic policy
        vm.startPrank(farmer1);
        
        uint256 premium = rainyDayFund.getPolicyPricing(RainyDayFund.PolicyType.BASIC);
        mockUSDC.approve(address(rainyDayFund), premium);
        
        uint256 tokenId = rainyDayFund.buyPolicy(RainyDayFund.PolicyType.BASIC);
        
        vm.stopPrank();
        
        // Assertions
        require(tokenId == 1, "First token ID should be 1");
        require(rainyDayFund.ownerOf(tokenId) == farmer1, "Token should be owned by farmer1");
        require(rainyDayFund.riskPoolBalance() == premium, "Risk pool should equal premium");
        require(mockUSDC.balanceOf(farmer1) == 1000 * 10**6 - premium, "Farmer balance should decrease by premium");
    }
    
    function test_Investment() public {
        vm.startPrank(investor1);
        
        uint256 investmentAmount = 1000 * 10**6; // 1000 USDC
        mockUSDC.approve(address(rainyDayFund), investmentAmount);
        
        rainyDayFund.invest(investmentAmount);
        
        vm.stopPrank();
        
        require(rainyDayFund.getUserInvestments(investor1) == investmentAmount, "Investment should be tracked");
        require(rainyDayFund.riskPoolBalance() == investmentAmount, "Risk pool should equal investment");
    }
    
    function test_RevertOnInsufficientBalance() public {
        address poorFarmer = address(0x3);
        
        vm.startPrank(poorFarmer);
        
        uint256 premium = rainyDayFund.getPolicyPricing(RainyDayFund.PolicyType.BASIC);
        mockUSDC.approve(address(rainyDayFund), premium);
        
        vm.expectRevert("Insufficient USDC balance");
        rainyDayFund.buyPolicy(RainyDayFund.PolicyType.BASIC);
        
        vm.stopPrank();
    }
}
