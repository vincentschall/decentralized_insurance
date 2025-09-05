import { useState, useEffect } from "react";
import FarmersTab from "./components/FarmersTab";
import InvestorsTab from "./components/InvestorsTab";
import logo from "./logo.jpg";

export default function App() {
  const [activeTab, setActiveTab] = useState("farmers");
  const [walletAddress, setWalletAddress] = useState("");
  const [ethBalance, setEthBalance] = useState("");
  const [isConnected, setIsConnected] = useState(false);

  // Check if MetaMask is installed
  const isMetaMaskInstalled = () => {
    return typeof window !== "undefined" && typeof window.ethereum !== "undefined";
  };

  // Connect to MetaMask
  const connectWallet = async () => {
    if (!isMetaMaskInstalled()) {
      alert("Please install MetaMask!");
      return;
    }

    try {
      // Force MetaMask to show account selector by requesting permissions
      await window.ethereum.request({
        method: "wallet_requestPermissions",
        params: [{ eth_accounts: {} }],
      });

      // Then request accounts (this will now show the selector)
      const accounts = await window.ethereum.request({
        method: "eth_requestAccounts",
      });
      
      if (accounts.length > 0) {
        setWalletAddress(accounts[0]);
        setIsConnected(true);
        await getBalance(accounts[0]);
      }
    } catch (error) {
      console.error("Failed to connect wallet:", error);
    }
  };

  // Get ETH balance
  const getBalance = async (address) => {
    try {
      const balance = await window.ethereum.request({
        method: "eth_getBalance",
        params: [address, "latest"],
      });
      
      // Convert from wei to ETH
      const ethBalance = parseInt(balance, 16) / Math.pow(10, 18);
      setEthBalance(ethBalance.toFixed(4));
    } catch (error) {
      console.error("Failed to get balance:", error);
    }
  };

  // Disconnect wallet
  const disconnectWallet = () => {
    setWalletAddress("");
    setEthBalance("");
    setIsConnected(false);
  };

  // Listen for account changes
  useEffect(() => {
    if (isMetaMaskInstalled()) {
      const handleAccountsChanged = (accounts) => {
        if (accounts.length > 0) {
          setWalletAddress(accounts[0]);
          getBalance(accounts[0]);
        } else {
          disconnectWallet();
        }
      };

      window.ethereum.on("accountsChanged", handleAccountsChanged);

      return () => {
        window.ethereum.removeListener("accountsChanged", handleAccountsChanged);
      };
    }
  }, []);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-b from-blue-50 via-white to-blue-50 relative overflow-hidden px-4">
      {/* Background Waves */}
      <div className="absolute top-0 left-0 w-full h-full -z-10">
        <svg className="w-full h-full" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="none">
          <path
            d="M0,160 C480,320 960,0 1440,160 L1440,0 L0,0 Z"
            fill="#cce9f5"
            opacity="0.5"
          />
          <path
            d="M0,200 C480,100 960,300 1440,200 L1440,0 L0,0 Z"
            fill="#2870ff"
            opacity="0.2"
          />
        </svg>
      </div>

      {/* Wallet Connection */}
      <div className="absolute top-4 right-4 z-10">
        {isConnected ? (
          <div className="bg-white rounded-lg shadow-lg p-4 max-w-xs">
            <div className="text-sm text-gray-600 mb-2">Connected Wallet</div>
            <div className="text-xs font-mono bg-gray-100 p-2 rounded mb-2">
              {walletAddress.slice(0, 6)}...{walletAddress.slice(-4)}
            </div>
            <div className="text-lg font-semibold text-[#2596be] mb-2">
              {ethBalance} ETH
            </div>
            <button
              onClick={disconnectWallet}
              className="w-full bg-red-500 text-white px-3 py-1 rounded text-sm hover:bg-red-600 transition-colors"
            >
              Disconnect
            </button>
          </div>
        ) : (
          <button
            onClick={connectWallet}
            className="bg-[#2870ff] text-white px-4 py-2 rounded-lg shadow-lg hover:bg-blue-600 transition-colors font-semibold"
          >
            Connect Wallet
          </button>
        )}
      </div>

      {/* Logo */}
      <img
        src={logo}
        alt="Logo"
        className="h-32 mb-6 rounded-lg shadow-xl object-contain z-10"
      />
      
      {/* Title */}
      <h1 className="text-4xl md:text-5xl font-extrabold mb-2 text-center text-[#2870ff] z-10">
        The Rainy Day Fund
      </h1>
      <p className="text-center text-gray-700 mb-8 max-w-2xl z-10">
        Turning droughts into liquidity! Protect your farm or invest in resilience.
      </p>
      
      {/* Tabs */}
      <div className="flex space-x-6 mb-8 z-10">
        <button
          className={`px-6 py-3 rounded-full font-semibold transition-all duration-300 shadow-md ${
            activeTab === "farmers"
              ? "bg-[#2870ff] text-white scale-105 shadow-lg"
              : "bg-blue-100 text-[#2870ff] hover:bg-[#2870ff] hover:text-white"
          }`}
          onClick={() => setActiveTab("farmers")}
        >
          Farmers
        </button>
        <button
          className={`px-6 py-3 rounded-full font-semibold transition-all duration-300 shadow-md ${
            activeTab === "investors"
              ? "bg-[#2870ff] text-white scale-105 shadow-lg"
              : "bg-blue-100 text-[#2870ff] hover:bg-[#2870ff] hover:text-white"
          }`}
          onClick={() => setActiveTab("investors")}
        >
          Investors
        </button>
      </div>
      
      {/* Active Tab */}
      <div className="w-full max-w-md z-10">
        {activeTab === "farmers" ? <FarmersTab /> : <InvestorsTab />}
      </div>
    </div>
  );
}
