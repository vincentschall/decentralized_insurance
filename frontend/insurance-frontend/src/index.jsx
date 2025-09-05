import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./styles/index.css";

import { WagmiConfig, createClient, configureChains, sepolia } from "wagmi";
import { publicProvider } from "wagmi/providers/public";

const { chains, provider } = configureChains([sepolia], [publicProvider()]);
const client = createClient({ autoConnect: true, provider });

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <WagmiConfig client={client}>
      <App />
    </WagmiConfig>
  </React.StrictMode>
);

