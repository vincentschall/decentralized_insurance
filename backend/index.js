import { ethers } from "ethers";
import express from "express";
import dotenv from "dotenv";

dotenv.config();

const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const app = express();

app.get('/', (req, res) => {
  res.send('Hello from Node.js server!')
});

const port = 3000;
app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
