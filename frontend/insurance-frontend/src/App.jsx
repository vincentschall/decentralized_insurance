import { useState } from "react";
import FarmersTab from "./components/FarmersTab";
import InvestorsTab from "./components/InvestorsTab";

export default function App() {
  const [activeTab, setActiveTab] = useState("farmers");

  return (
    <div className="min-h-screen flex flex-col items-center p-8 bg-gray-50">
      <h1 className="text-4xl font-bold mb-6">The rainy day fund - turning droughts into liquidity!</h1>

      {/* Tabs */}
      <div className="flex space-x-4 mb-6">
        <button
          className={`px-4 py-2 rounded ${
            activeTab === "farmers" ? "bg-green-600 text-white" : "bg-gray-200"
          }`}
          onClick={() => setActiveTab("farmers")}
        >
          Farmers
        </button>
        <button
          className={`px-4 py-2 rounded ${
            activeTab === "investors" ? "bg-green-600 text-white" : "bg-gray-200"
          }`}
          onClick={() => setActiveTab("investors")}
        >
          Investors
        </button>
      </div>

      {/* Active Tab */}
      {activeTab === "farmers" ? <FarmersTab /> : <InvestorsTab />}
    </div>
  );
}
