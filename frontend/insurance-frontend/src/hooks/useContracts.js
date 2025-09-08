import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

// Import the generated deployment info
import deployments from '../contracts/deployments.json';

export const useContracts = () => {
  const [contracts, setContracts] = useState(null);
  const [signer, setSigner] = useState(null);
  const [address, setAddress] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const initContracts = async () => {
      if (window.ethereum) {
        try {
          const provider = new ethers.providers.Web3Provider(window.ethereum);
          const signer = provider.getSigner();
          const address = await signer.getAddress();

          const rainyDayFund = new ethers.Contract(
            deployments.rainyDayFund.address,
            deployments.rainyDayFund.abi,
            signer
          );

          const mockUSDC = new ethers.Contract(
            deployments.mockUSDC.address,
            deployments.mockUSDC.abi,
            signer
          );

          setContracts({ rainyDayFund, mockUSDC });
          setSigner(signer);
          setAddress(address);
        } catch (error) {
          console.error("Error initializing contracts:", error);
        }
      }
      setLoading(false);
    };

    initContracts();
  }, []);

  return { contracts, signer, address, loading };
};
