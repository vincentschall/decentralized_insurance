import { ethers } from "ethers";
import express from "express";
import dotenv from "dotenv";

dotenv.config();

const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const app = express();

app.get("/balance", async (req, res) => {
  try {
    const balance = await provider.getBalance(wallet.address);
    res.send(`Balance of ${wallet.address}: ${ethers.formatEther(balance)} SepoliaETH`);
  } catch (err) {
    console.error(err);
    res.status(500).send("Error fetching balance");
  }
});
const port = 3000;
app.listen(port, () => {
console.log(`Server listening on port ${port}`);
});
