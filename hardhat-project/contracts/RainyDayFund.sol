// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Interface for USDC (ERC20) token
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract RainyDayFund {
    // Maximum gas per transaction (adjust based on network conditions)
    uint256 public constant MAX_GAS_PER_BATCH = 5000000; // ~5M gas limit

    // USDC contract
    IERC20 public immutable usdc;

    // Owner of the contract
    address public owner;

    // Total risk pool balance in USDC
    uint256 public riskPoolBalance;

    // Investor funds tracked separately
    uint256 public totalInvestorFunds;

    // Token counter for unique policy IDs
    uint256 private tokenCounter;

    // Array to track users for payouts
    address[] private allFarmers;
    mapping(address => bool) private isFarmer;

    // Last processed tokenId (monotonic)
    uint256 public lastProcessedTokenId;

    // Resume indices for batch processing
    uint256 public lastFarmerIndex;
    uint256 public lastTokenIndex;

    // Policy types
    enum PolicyType {
        BASIC,      // 100 USDC premium
        STANDARD,   // 250 USDC premium  
        PREMIUM     // 500 USDC premium
    }

    // Policy pricing (USDC - 6 decimals)
    mapping(PolicyType => uint256) public premiums;

    // Mapping for policies by tokenId (one policy per token)
    struct Policy {
        uint256 creationTimestamp;
        uint256 expirationTimestamp;
        uint256 payoutAmount;
        bytes32 locationHash;        // hashed location
        uint256 weatherData;         // fetched weather data (e.g., rainfall)
        bool weatherDataFetched;     // weather data is available
        bool payoutDone;             // payout already occurred
    }
    mapping(uint256 => Policy) public policies; // tokenId => Policy

    // Token ownership
    mapping(uint256 => address) public tokenOwner; // tokenId => owner
    mapping(address => uint256[]) public farmerTokens; // farmer => tokenIds

    // Investment tracking
    mapping(address => uint256) public investorShares; // investor => pool share

    // Events
    event PolicyBoughtEvent(
        address indexed farmer,
        uint256 indexed tokenId,
        PolicyType policyType,
        uint256 premium,
        uint256 timestamp
    );

    event InvestmentMadeEvent(
        address indexed investor,
        uint256 amount,
        uint256 timestamp
    );

    event InvestmentWithdrawnEvent(
        address indexed investor,
        uint256 amount,
        uint256 timestamp
    );

    event FarmerAdded(address indexed farmer, uint256 timestamp);
    event FarmerRemoved(address indexed farmer, uint256 timestamp);

    event BatchProcessingStarted(uint256 maxProcess, uint256 timestamp);
    event BatchProcessingCompleted(uint256 processed, uint256 gasUsed, uint256 timestamp);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier validPolicyType(PolicyType _policyType) {
        require(uint8(_policyType) <= 2, "Invalid policy type");
        _;
    }

    constructor(address _usdcAddress) {
        owner = msg.sender;
        usdc = IERC20(_usdcAddress);
        tokenCounter = 1;
        lastProcessedTokenId = 0;
        lastFarmerIndex = 0;
        lastTokenIndex = 0;

        // Set premiums
        premiums[PolicyType.BASIC] = 100 * 10**6;
        premiums[PolicyType.STANDARD] = 250 * 10**6;
        premiums[PolicyType.PREMIUM] = 500 * 10**6;
    }

    /**
     * @dev Farmers buy policies
     */
    function buyPolicy(PolicyType _policyType) external validPolicyType(_policyType) returns (uint256 tokenId) {
        uint256 premiumAmount = premiums[_policyType];
        require(usdc.balanceOf(msg.sender) >= premiumAmount, "Insufficient USDC");
        require(usdc.allowance(msg.sender, address(this)) >= premiumAmount, "Allowance too low");

        require(usdc.transferFrom(msg.sender, address(this), premiumAmount), "Transfer failed");

        tokenId = tokenCounter++;
        tokenOwner[tokenId] = msg.sender;
        farmerTokens[msg.sender].push(tokenId);

        if (!isFarmer[msg.sender]) {
            isFarmer[msg.sender] = true;
            allFarmers.push(msg.sender);
            emit FarmerAdded(msg.sender, block.timestamp);
        }

        policies[tokenId] = Policy({
            creationTimestamp: block.timestamp,
            expirationTimestamp: block.timestamp + 30 days,
            payoutAmount: premiumAmount * 2,
            locationHash: keccak256(abi.encodePacked(msg.sender, tokenId)),
            weatherData: 0,
            weatherDataFetched: false,
            payoutDone: false
        });

        riskPoolBalance += premiumAmount;

        emit PolicyBoughtEvent(msg.sender, tokenId, _policyType, premiumAmount, block.timestamp);

        return tokenId;
    }

    /**
     * @dev Removes a farmer from allFarmers if they have no active tokens.
     */
    function _removeFarmer(address farmer) internal {
        if (farmerTokens[farmer].length == 0 && isFarmer[farmer]) {
            isFarmer[farmer] = false;

            // Find and remove from array
            uint256 len = allFarmers.length;
            for (uint256 i = 0; i < len; i++) {
                if (allFarmers[i] == farmer) {
                    allFarmers[i] = allFarmers[len - 1];
                    allFarmers.pop();
                    break;
                }
            }

            emit FarmerRemoved(farmer, block.timestamp);
        }
    }

    /**
     * @dev Batch payout
     */
    function batchPayout(uint256 _maxProcess, uint256 _gasBuffer) external onlyOwner {
        require(_gasBuffer < 1000000, "Gas buffer too large");

        uint256 startGas = gasleft();
        uint256 gasBuffer = _gasBuffer > 0 ? _gasBuffer : 200000;
        uint256 maxProcess = _maxProcess > 0 ? _maxProcess :
                            (MIN(MAX_GAS_PER_BATCH - gasBuffer, gasleft() - gasBuffer) / 50000);

        emit BatchProcessingStarted(maxProcess, block.timestamp);

        uint256 processed = 0;
        uint256 farmersLength = allFarmers.length;

        uint256 i = lastFarmerIndex;
        uint256 j = lastTokenIndex;

        uint256 gasUsed = 0;

        for (; i < farmersLength && processed < maxProcess; ) {
            address farmer = allFarmers[i];
            uint256[] storage tokens = farmerTokens[farmer];
            uint256 tokensLength = tokens.length;

            for (; j < tokensLength && processed < maxProcess; ) {
                uint256 tokenId = tokens[j];

                if (tokenId > lastProcessedTokenId) {
                    Policy storage policy = policies[tokenId];

                    if (!policy.payoutDone &&
                        policy.weatherDataFetched &&
                        block.timestamp > policy.expirationTimestamp &&
                        checkChainLink(tokenId) &&
                        policy.weatherData < 10) {

                        if (riskPoolBalance >= policy.payoutAmount) {
                            require(usdc.transfer(farmer, policy.payoutAmount), "Transfer failed");
                            riskPoolBalance -= policy.payoutAmount;
                            policy.payoutDone = true;
                            processed++;
                            lastProcessedTokenId = tokenId;

                            // Remove token from farmer's list
                            tokens[j] = tokens[tokensLength - 1];
                            tokens.pop();
                            tokensLength--;

                            // Cleanup farmer if no tokens remain
                            if (tokensLength == 0) {
                                _removeFarmer(farmer);
                            }

                            continue; // recheck current j (new token swapped in)
                        } else {
                            revert("Insufficient funds in risk pool");
                        }
                    }
                }

                j++;

                if (gasleft() < gasBuffer) {
                    lastFarmerIndex = i;
                    lastTokenIndex = j;
                    gasUsed = startGas - gasleft();
                    emit BatchProcessingCompleted(processed, gasUsed, block.timestamp);
                    return;
                }
            }

            i++;
            j = 0;
        }

        lastFarmerIndex = 0;
        lastTokenIndex = 0;
        gasUsed = startGas - gasleft();
        emit BatchProcessingCompleted(processed, gasUsed, block.timestamp);
    }

    function resetBatchProcessing() external onlyOwner {
        lastProcessedTokenId = 0;
        lastFarmerIndex = 0;
        lastTokenIndex = 0;
    }

    function getBatchStatus() external view returns (uint256 lastProcessed, uint256 remainingTokens, uint256 resumeFarmerIndex, uint256 resumeTokenIndex) {
        uint256 totalTokens = tokenCounter - 1;
        uint256 processed = lastProcessedTokenId;
        uint256 remaining = totalTokens > processed ? (totalTokens - processed) : 0;
        return (processed, remaining, lastFarmerIndex, lastTokenIndex);
    }

    function MIN(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function checkChainLink(uint256 _tokenId) internal view returns (bool conditionMet) {
        return ((block.timestamp + _tokenId) % 2) == 0;
    }

    function updateWeatherData(uint256 _tokenId, uint256 _rainfall) external onlyOwner {
        Policy storage policy = policies[_tokenId];
        require(policy.creationTimestamp != 0, "Policy not found");
        require(!policy.weatherDataFetched, "Already fetched");
        policy.weatherData = _rainfall;
        policy.weatherDataFetched = true;
    }

    function payout(uint256 _tokenId) external {
        Policy storage policy = policies[_tokenId];
        address policyHolder = tokenOwner[_tokenId];

        require(policy.creationTimestamp != 0, "Policy not found");
        require(block.timestamp > policy.expirationTimestamp, "Crop season not over");
        require(policy.weatherDataFetched, "Weather data not available");
        require(!policy.payoutDone, "Already paid");
        require(checkChainLink(_tokenId), "Weather condition not met");
        require(riskPoolBalance >= policy.payoutAmount, "Insufficient pool funds");

        if (policy.weatherData < 10) {
            require(usdc.transfer(policyHolder, policy.payoutAmount), "USDC payout failed");
            riskPoolBalance -= policy.payoutAmount;
            policy.payoutDone = true;

            // Remove token from farmer
            uint256[] storage tokens = farmerTokens[policyHolder];
            for (uint256 i = 0; i < tokens.length; i++) {
                if (tokens[i] == _tokenId) {
                    tokens[i] = tokens[tokens.length - 1];
                    tokens.pop();
                    break;
                }
            }
            if (tokens.length == 0) {
                _removeFarmer(policyHolder);
            }
        }
    }

    // ---------------- Investor logic ----------------

    function invest(uint256 _amount) external {
        require(_amount > 0, "Investment amount must be greater than 0");
        require(usdc.balanceOf(msg.sender) >= _amount, "Insufficient USDC balance");
        require(usdc.allowance(msg.sender, address(this)) >= _amount, "Insufficient USDC allowance");
        require(usdc.transferFrom(msg.sender, address(this), _amount), "USDC transfer failed");

        investorShares[msg.sender] += _amount;
        totalInvestorFunds += _amount;
        riskPoolBalance += _amount;

        emit InvestmentMadeEvent(msg.sender, _amount, block.timestamp);
    }

    function withdrawInvestment(uint256 _shareAmount) external {
        uint256 investorShare = investorShares[msg.sender];
        require(investorShare >= _shareAmount && _shareAmount > 0, "Invalid share amount");

        // Calculate proportional withdrawal from the pool
        uint256 withdrawAmount = (_shareAmount * riskPoolBalance) / totalInvestorFunds;

        investorShares[msg.sender] -= _shareAmount;
        totalInvestorFunds -= _shareAmount;
        riskPoolBalance -= withdrawAmount;

        require(usdc.transfer(msg.sender, withdrawAmount), "USDC withdrawal failed");

        emit InvestmentWithdrawnEvent(msg.sender, withdrawAmount, block.timestamp);
    }

    // ---------------- Getters ----------------

    function getFarmerTokens(address _farmer) external view returns (uint256[] memory) {
        return farmerTokens[_farmer];
    }

    function getPolicyPricing(PolicyType _policyType) external view validPolicyType(_policyType) returns (uint256 premium) {
        return premiums[_policyType];
    }

    function tokenExists(uint256 _tokenId) external view returns (bool) {
        return tokenOwner[_tokenId] != address(0);
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        require(tokenOwner[_tokenId] != address(0), "Token does not exist");
        return tokenOwner[_tokenId];
    }

    function getTotalPolicies() external view returns (uint256) {
        return tokenCounter - 1;
    }

    function getContractUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function getUserInvestments(address _investor) external view returns (uint256) {
        return investorShares[_investor];
    }

    function getUSDCAddress() external view returns (address) {
        return address(usdc);
    }
}
