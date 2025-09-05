import { useState } from "react";
import FarmersTab from "./components/FarmersTab";
import InvestorsTab from "./components/InvestorsTab";
import logo from "./logo.jpg";

export default function App() {
  const [activeTab, setActiveTab] = useState("farmers");

  return (
    <div className="relative min-h-screen flex flex-col items-center justify-center bg-gradient-to-b from-blue-50 via-white to-blue-50 overflow-hidden px-4">

      {/* Background Waves */}
      <div className="absolute inset-0 -z-10">
        <svg
          className="w-full h-full object-cover"
          xmlns="http://www.w3.org/2000/svg"
          preserveAspectRatio="none"
        >
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

