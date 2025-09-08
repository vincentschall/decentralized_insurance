const { ethers } = require("hardhat");
require("dotenv").config();

// MockUSDC contract ABI - based on your contract
const MOCK_USDC_ABI = [
  "function mint(address to, uint256 amount) external",
  "function faucet() external", 
  "function balanceOf(address account) public view returns (uint256)",
  "function decimals() public view returns (uint8)",
  "function symbol() public view returns (string)",
  "function name() public view returns (string)",
  "function totalSupply() public view returns (uint256)"
];

async function main() {
  // Configuration
  const MOCK_USDC_ADDRESS = process.env.MOCK_USDC_ADDRESS || "YOUR_MOCK_USDC_CONTRACT_ADDRESS";
  const RECIPIENT_ADDRESS = process.env.RECIPIENT_ADDRESS || process.argv[2];
  const FAUCET_AMOUNT = process.env.FAUCET_AMOUNT || "1000"; // Default 1000 MUSDC
  const USE_MINT = process.env.USE_MINT === "true" || process.argv[3] === "--mint";
  
  // Validation
  if (!MOCK_USDC_ADDRESS || MOCK_USDC_ADDRESS === "YOUR_MOCK_USDC_CONTRACT_ADDRESS") {
    console.error("❌ Please set MOCK_USDC_ADDRESS in your .env file or update the script");
    process.exit(1);
  }
  
  if (!RECIPIENT_ADDRESS && USE_MINT) {
    console.error("❌ Please provide recipient address for mint function or use faucet without address");
    console.log("Usage for mint: npx hardhat run scripts/faucet-mockusdc.js --network sepolia 0xRecipientAddress --mint");
    console.log("Usage for faucet: npx hardhat run scripts/faucet-mockusdc.js --network sepolia");
    process.exit(1);
  }

  // Validate address format only if using mint
  if (RECIPIENT_ADDRESS && !ethers.isAddress(RECIPIENT_ADDRESS)) {
    console.error("❌ Invalid recipient address format");
    process.exit(1);
  }

  console.log("🚰 MockUSDC Faucet Script");
  console.log("========================");
  console.log(`📍 MockUSDC Contract: ${MOCK_USDC_ADDRESS}`);
  
  if (USE_MINT && RECIPIENT_ADDRESS) {
    console.log(`👤 Recipient: ${RECIPIENT_ADDRESS}`);
    console.log(`💰 Amount: ${FAUCET_AMOUNT} MUSDC (using mint function)`);
  } else {
    console.log(`💰 Amount: 1000 MUSDC (using faucet function - fixed amount)`);
  }

  try {
    // Get signer
    const [signer] = await ethers.getSigners();
    console.log(`🔑 Using signer: ${signer.address}`);

    // Connect to MockUSDC contract
    const mockUSDC = new ethers.Contract(MOCK_USDC_ADDRESS, MOCK_USDC_ABI, signer);

    // Get token info
    try {
      const name = await mockUSDC.name();
      const symbol = await mockUSDC.symbol();
      const decimals = await mockUSDC.decimals();
      const totalSupply = await mockUSDC.totalSupply();
      
      console.log(`🪙 Token: ${name} (${symbol}), Decimals: ${decimals}`);
      console.log(`📊 Total Supply: ${ethers.formatUnits(totalSupply, decimals)} ${symbol}`);
      
      let targetAddress;
      let balanceBefore;
      let tx;

      if (USE_MINT && RECIPIENT_ADDRESS) {
        // Using mint function to send to specific address
        targetAddress = RECIPIENT_ADDRESS;
        const amountWei = ethers.parseUnits(FAUCET_AMOUNT, decimals);
        
        balanceBefore = await mockUSDC.balanceOf(targetAddress);
        console.log(`💳 Balance before: ${ethers.formatUnits(balanceBefore, decimals)} ${symbol}`);
        
        console.log("🔄 Calling mint function...");
        tx = await mockUSDC.mint(targetAddress, amountWei);
        
      } else {
        // Using faucet function (sends to caller, fixed 1000 MUSDC)
        targetAddress = signer.address;
        
        balanceBefore = await mockUSDC.balanceOf(targetAddress);
        console.log(`💳 Balance before: ${ethers.formatUnits(balanceBefore, decimals)} ${symbol}`);
        
        console.log("🔄 Calling faucet function (1000 MUSDC to your address)...");
        tx = await mockUSDC.faucet();
      }

      console.log(`⏳ Transaction hash: ${tx.hash}`);
      console.log("⏳ Waiting for confirmation...");
      
      const receipt = await tx.wait();
      console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);
      console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);

      // Check balance after
      const balanceAfter = await mockUSDC.balanceOf(targetAddress);
      console.log(`💳 Balance after: ${ethers.formatUnits(balanceAfter, decimals)} ${symbol}`);
      
      const difference = balanceAfter - balanceBefore;
      console.log(`📈 Tokens received: ${ethers.formatUnits(difference, decimals)} ${symbol}`);

      console.log("\n🎉 Faucet completed successfully!");

    } catch (contractError) {
      console.error("❌ Error interacting with contract:", contractError.message);
      console.log("\n💡 Make sure:");
      console.log("- The contract address is correct");
      console.log("- You're on the right network (Sepolia)");
      console.log("- You have enough ETH for gas fees");
      console.log("- For mint function: you might need to be the contract owner");
    }

  } catch (error) {
    console.error("❌ Script failed:", error.message);
    process.exit(1);
  }
}

// Execute the main function
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
