import { network } from "hardhat";
import { parseUnits, formatUnits } from "viem";

const { viem } = await network.connect();

console.log("🌧️  RainyDayFund Demo Script");
console.log("================================");

// Get wallet clients
const [deployer, farmer, investor] = await viem.getWalletClients();
const publicClient = await viem.getPublicClient();

console.log("Deployer:", deployer.account.address);
console.log("Farmer:", farmer.account.address);
console.log("Investor:", investor.account.address);

// Deploy contracts
console.log("\n📦 Deploying contracts...");
const mockUSDC = await viem.deployContract("MockUSDC");
const rainyDayFund = await viem.deployContract("RainyDayFund", [mockUSDC.address]);

console.log("MockUSDC deployed at:", mockUSDC.address);
console.log("RainyDayFund deployed at:", rainyDayFund.address);

// Give tokens to farmer and investor
console.log("\n💰 Distributing USDC tokens...");
await mockUSDC.write.mint([farmer.account.address, parseUnits("1000", 6)]);
await mockUSDC.write.mint([investor.account.address, parseUnits("5000", 6)]);

const farmerBalance = await mockUSDC.read.balanceOf([farmer.account.address]);
const investorBalance = await mockUSDC.read.balanceOf([investor.account.address]);

console.log(`Farmer USDC balance: ${formatUnits(farmerBalance, 6)} USDC`);
console.log(`Investor USDC balance: ${formatUnits(investorBalance, 6)} USDC`);

// Farmer buys a standard policy
console.log("\n🛡️  Farmer buying STANDARD policy...");
const standardPremium = await rainyDayFund.read.getPolicyPricing([1]); // STANDARD = 1
console.log(`Standard policy premium: ${formatUnits(standardPremium, 6)} USDC`);

await mockUSDC.write.approve([rainyDayFund.address, standardPremium], { 
  account: farmer.account 
});

const policyTx = await rainyDayFund.write.buyPolicy([1], { 
  account: farmer.account 
});

const receipt = await publicClient.waitForTransactionReceipt({ hash: policyTx });
console.log("Policy purchased! Transaction:", receipt.transactionHash);

// Check farmer's tokens
const farmerTokens = await rainyDayFund.read.getFarmerTokens([farmer.account.address]);
console.log(`Farmer's policy tokens: [${farmerTokens.join(", ")}]`);

// Investor makes an investment
console.log("\n💼 Investor investing in risk pool...");
const investmentAmount = parseUnits("2000", 6); // 2000 USDC
console.log(`Investment amount: ${formatUnits(investmentAmount, 6)} USDC`);

await mockUSDC.write.approve([rainyDayFund.address, investmentAmount], { 
  account: investor.account 
});

const investTx = await rainyDayFund.write.invest([investmentAmount], { 
  account: investor.account 
});

const investReceipt = await publicClient.waitForTransactionReceipt({ hash: investTx });
console.log("Investment made! Transaction:", investReceipt.transactionHash);

// Check final state
console.log("\n📊 Final State:");
const riskPoolBalance = await rainyDayFund.read.riskPoolBalance();
const totalPolicies = await rainyDayFund.read.getTotalPolicies();
const userInvestments = await rainyDayFund.read.getUserInvestments([investor.account.address]);

console.log(`Risk Pool Balance: ${formatUnits(riskPoolBalance, 6)} USDC`);
console.log(`Total Policies: ${totalPolicies}`);
console.log(`Investor's Total Investment: ${formatUnits(userInvestments, 6)} USDC`);

console.log("\n✅ Demo completed successfully!");
