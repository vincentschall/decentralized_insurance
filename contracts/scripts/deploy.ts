async function main() {
    // Import hardhat dynamically
    const hre = await import("hardhat");
    
    // Get signers
    const signers = await hre.ethers.getSigners();
    const [deployer] = signers;
    
    console.log("Deploying contracts with account:", deployer.address);
    
    // Check balance
    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", hre.ethers.formatEther(balance), "ETH");
    
    // 1. Deploy Mock USDC
    console.log("\nDeploying Mock USDC...");
    const MockUSDC = await hre.ethers.getContractFactory("MockUSDC");
    const mockUSDC = await MockUSDC.deploy();
    await mockUSDC.waitForDeployment();
    const mockUSDCAddress = await mockUSDC.getAddress();
    console.log("Mock USDC deployed to:", mockUSDCAddress);
    
    // 2. Deploy RainyDayFund
    console.log("\nDeploying RainyDayFund...");
    const RainyDayFund = await hre.ethers.getContractFactory("RainyDayFund");
    const rainyDayFund = await RainyDayFund.deploy(mockUSDCAddress);
    await rainyDayFund.waitForDeployment();
    const rainyDayFundAddress = await rainyDayFund.getAddress();
    console.log("RainyDayFund deployed to:", rainyDayFundAddress);
    
    console.log("\n--- Deployment Summary ---");
    console.log(`Mock USDC: ${mockUSDCAddress}`);
    console.log(`RainyDayFund: ${rainyDayFundAddress}`);
    console.log(`Network: sepolia`);
    
    // Save addresses to JSON file
    const fs = await import('fs');
    const contractAddresses = {
        mockUSDC: mockUSDCAddress,
        rainyDayFund: rainyDayFundAddress,
        network: "sepolia",
        deployedAt: new Date().toISOString()
    };
    
    fs.writeFileSync('contract-addresses.json', JSON.stringify(contractAddresses, null, 2));
    console.log("\n📝 Contract addresses saved to contract-addresses.json");
    
    console.log("\n🎉 Deployment completed successfully!");
    console.log("\n--- Next Steps ---");
    console.log("1. Call mockUSDC.faucet() to get 1000 MUSDC test tokens");
    console.log("2. Call mockUSDC.approve(rainyDayFundAddress, amount) to approve spending");
    console.log("3. Call rainyDayFund.buyPolicy(0) to buy a BASIC policy");
    console.log("4. Call rainyDayFund.invest(amount) to invest in the risk pool");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Error during deployment:");
        console.error(error);
        process.exit(1);
    });
