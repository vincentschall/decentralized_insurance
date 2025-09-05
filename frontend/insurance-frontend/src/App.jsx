import { useState } from "react";
import FarmersTab from "./components/FarmersTab";
import InvestorsTab from "./components/InvestorsTab";
import logo from "./logo.jpg"; // make sure your logo is in src/

export default function App() {
  const [activeTab, setActiveTab] = useState("farmers");
  const primaryBlue = "#2596be";

  return (
    <div className="min-h-screen flex flex-col items-center bg-gradient-to-b from-white to-blue-50 p-8">
      {/* Logo */}
      <img src={logo} alt="Logo" className="w-32 h-32 mb-6 rounded-full shadow-lg" />

      {/* Title */}
      <h1 className="text-4xl md:text-5xl font-extrabold mb-6 text-center text-gray-800">
        The Rainy Day Fund
      </h1>
      <p className="text-center text-gray-600 mb-8 max-w-xl">
        Turning droughts into liquidity! Protect your farm or invest in resilience.
      </p>

      {/* Tabs */}
      <div className="flex space-x-4 mb-8">
        <button
          className={`px-6 py-3 rounded-full font-semibold transition-all duration-300 shadow-md ${
            activeTab === "farmers"
              ? "bg-[#2596be] text-white scale-105 shadow-lg"
              : "bg-blue-100 text-[#2596be] hover:bg-[#2596be] hover:text-white"
          }`}
          onClick={() => setActiveTab("farmers")}
        >
          Farmers
        </button>
        <button
          className={`px-6 py-3 rounded-full font-semibold transition-all duration-300 shadow-md ${
            activeTab === "investors"
              ? "bg-[#2596be] text-white scale-105 shadow-lg"
              : "bg-blue-100 text-[#2596be] hover:bg-[#2596be] hover:text-white"
          }`}
          onClick={() => setActiveTab("investors")}
        >
          Investors
        </button>
      </div>

      {/* Active Tab */}
      <div className="w-full max-w-md">
        {activeTab === "farmers" ? <FarmersTab /> : <InvestorsTab />}
      </div>
    </div>
  );
}

