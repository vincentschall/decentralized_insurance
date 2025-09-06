import { useState } from 'react';

export default function FarmersTab() {
  const [selectedPolicy, setSelectedPolicy] = useState(null);

  const policies = [
    {
      id: 'basic',
      name: 'Basic',
      price: 'TBD USDC',
      icon: '🌱',
      color: 'from-green-400 to-green-600',
      bgColor: 'bg-green-50',
      borderColor: 'border-green-200',
      textColor: 'text-green-700'
    },
    {
      id: 'standard',
      name: 'Standard',
      price: 'TBD USDC',
      icon: '⛈️',
      color: 'from-blue-500 to-blue-700',
      bgColor: 'bg-blue-50',
      borderColor: 'border-blue-200',
      textColor: 'text-blue-700'
    },
    {
      id: 'premium',
      name: 'Premium',
      price: 'TBD USDC',
      icon: '👑',
      color: 'from-purple-500 to-purple-700',
      bgColor: 'bg-purple-50',
      borderColor: 'border-purple-200',
      textColor: 'text-purple-700'
    }
  ];

  const handlePolicySelect = (policyId) => {
    setSelectedPolicy(policyId);
  };

  const handlePurchase = () => {
    if (selectedPolicy) {
      const policy = policies.find(p => p.id === selectedPolicy);
      alert(`Purchasing ${policy.name} for ${policy.price}. Smart contract integration coming soon!`);
    }
  };

  return (
    <div className="bg-white p-6 rounded-3xl shadow-2xl">
      <div className="text-center mb-8">
        <h2 className="text-3xl font-bold text-[#2870ff] mb-2">Choose Your Protection</h2>
        <p className="text-gray-600">Select the insurance plan that fits your farm's needs</p>
      </div>

      <div className="space-y-4 mb-8">
        {policies.map((policy) => (
          <div
            key={policy.id}
            className={`relative cursor-pointer transition-all duration-300 transform hover:scale-102 ${
              selectedPolicy === policy.id 
                ? `${policy.bgColor} ${policy.borderColor} border-2 scale-102 shadow-lg` 
                : 'bg-gray-50 border border-gray-200 hover:shadow-md'
            }`}
            onClick={() => handlePolicySelect(policy.id)}
            style={{ borderRadius: '1rem' }}
          >
            <div className="p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="text-3xl">{policy.icon}</div>
                  <div>
                    <h3 className={`text-xl font-bold ${selectedPolicy === policy.id ? policy.textColor : 'text-gray-800'}`}>
                      {policy.name}
                    </h3>
                  </div>
                </div>
                <div className="text-right">
                  <div className={`text-2xl font-bold ${selectedPolicy === policy.id ? policy.textColor : 'text-gray-800'}`}>
                    {policy.price}
                  </div>
                </div>
              </div>
            </div>

            {selectedPolicy === policy.id && (
              <div className={`absolute inset-0 bg-gradient-to-r ${policy.color} opacity-10 rounded-2xl`}></div>
            )}
          </div>
        ))}
      </div>

      <div className="text-center">
        {selectedPolicy ? (
          <div className="space-y-4">
            <div className="p-4 bg-gray-100 rounded-xl">
              <p className="text-sm text-gray-600 mb-2">Selected Plan:</p>
              <p className="font-semibold text-lg text-gray-800">
                {policies.find(p => p.id === selectedPolicy)?.name} - {policies.find(p => p.id === selectedPolicy)?.price}
              </p>
            </div>
            <button
              onClick={handlePurchase}
              className="w-full py-4 bg-gradient-to-r from-[#2870ff] to-blue-600 text-white font-bold rounded-2xl shadow-lg hover:from-blue-600 hover:to-blue-700 transition-all duration-300 transform hover:scale-105"
            >
              Purchase Policy 🚀
            </button>
          </div>
        ) : (
          <p className="text-gray-500 py-4">Select a policy above to continue</p>
        )}
      </div>

      <div className="mt-6 p-4 bg-yellow-50 border border-yellow-200 rounded-xl">
        <div className="flex items-center space-x-2 mb-2">
          <span className="text-yellow-600">💡</span>
          <span className="font-semibold text-yellow-800">Smart Tip</span>
        </div>
        <p className="text-sm text-yellow-700">
          Weather data is sourced from multiple satellite providers and verified through our decentralized oracle network for maximum accuracy and transparency.
        </p>
      </div>
    </div>
  );
}
