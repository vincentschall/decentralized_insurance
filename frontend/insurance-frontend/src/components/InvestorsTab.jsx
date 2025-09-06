import { useState } from 'react';

export default function InvestorsTab() {
  const [selectedPool, setSelectedPool] = useState(null);

  const pools = [
    {
      id: 'conservative',
      name: 'Conservative Pool',
      apy: 'TBD %',
      icon: '🛡️',
      color: 'from-green-400 to-green-600',
      bgColor: 'bg-green-50',
      borderColor: 'border-green-200',
      textColor: 'text-green-700'
    },
    {
      id: 'balanced',
      name: 'Balanced Pool',
      apy: 'TBD %',
      icon: '⚖️',
      color: 'from-blue-500 to-blue-700',
      bgColor: 'bg-blue-50',
      borderColor: 'border-blue-200',
      textColor: 'text-blue-700'
    },
    {
      id: 'aggressive',
      name: 'High Yield Pool',
      apy: 'TBD %',
      icon: '🚀',
      color: 'from-purple-500 to-purple-700',
      bgColor: 'bg-purple-50',
      borderColor: 'border-purple-200',
      textColor: 'text-purple-700'
    }
  ];

  const handlePoolSelect = (poolId) => {
    setSelectedPool(poolId);
  };

  const handleInvest = () => {
    if (selectedPool) {
      const pool = pools.find(p => p.id === selectedPool);
      alert(`Investing in ${pool.name} with ${pool.apy} APY. Smart contract integration coming soon!`);
    }
  };

  return (
    <div className="bg-white p-6 rounded-3xl shadow-2xl">
      <div className="text-center mb-8">
        <h2 className="text-3xl font-bold text-[#2870ff] mb-2">Investment Pools</h2>
        <p className="text-gray-600">Choose your risk level and earn from weather insurance premiums</p>
      </div>

      <div className="space-y-4 mb-8">
        {pools.map((pool) => (
          <div
            key={pool.id}
            className={`relative cursor-pointer transition-all duration-300 transform hover:scale-102 ${
              selectedPool === pool.id 
                ? `${pool.bgColor} ${pool.borderColor} border-2 scale-102 shadow-lg` 
                : 'bg-gray-50 border border-gray-200 hover:shadow-md'
            }`}
            onClick={() => handlePoolSelect(pool.id)}
            style={{ borderRadius: '1rem' }}
          >
            <div className="p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="text-3xl">{pool.icon}</div>
                  <div>
                    <h3 className={`text-xl font-bold ${selectedPool === pool.id ? pool.textColor : 'text-gray-800'}`}>
                      {pool.name}
                    </h3>
                  </div>
                </div>
                <div className="text-right">
                  <div className={`text-2xl font-bold ${selectedPool === pool.id ? pool.textColor : 'text-gray-800'}`}>
                    {pool.apy}
                  </div>
                </div>
              </div>
            </div>

            {selectedPool === pool.id && (
              <div className={`absolute inset-0 bg-gradient-to-r ${pool.color} opacity-10 rounded-2xl`}></div>
            )}
          </div>
        ))}
      </div>

      <div className="text-center">
        {selectedPool ? (
          <div className="space-y-4">
            <div className="p-4 bg-gray-100 rounded-xl">
              <p className="text-sm text-gray-600 mb-2">Selected Pool:</p>
              <p className="font-semibold text-lg text-gray-800">
                {pools.find(p => p.id === selectedPool)?.name} - {pools.find(p => p.id === selectedPool)?.apy} APY
              </p>
            </div>
            <button
              onClick={handleInvest}
              className="w-full py-4 bg-gradient-to-r from-[#2870ff] to-blue-600 text-white font-bold rounded-2xl shadow-lg hover:from-blue-600 hover:to-blue-700 transition-all duration-300 transform hover:scale-105"
            >
              Start Investing 💰
            </button>
          </div>
        ) : (
          <p className="text-gray-500 py-4">Select an investment pool above to continue</p>
        )}
      </div>

      <div className="mt-6 p-4 bg-yellow-50 border border-yellow-200 rounded-xl">
        <div className="flex items-center space-x-2 mb-2">
          <span className="text-yellow-600">💡</span>
          <span className="font-semibold text-yellow-800">Investment Tip</span>
        </div>
        <p className="text-sm text-yellow-700">
          Your returns come from insurance premiums collected from farmers. When weather events are rare, investors earn higher yields!
        </p>
      </div>
    </div>
  );
}
