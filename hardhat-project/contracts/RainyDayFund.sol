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
    // USDC contract
    IERC20 public immutable usdc;

    // Owner of the contract
    address public owner;

    // Premium farmers pay per policy token
    uint256 public premium; 

    // Total risk pool balance in USDC
    uint256 public riskPoolBalance;

    // Investor funds tracked separately
    uint256 public totalInvestorFunds;

    // Token counter for unique policy IDs
    uint256 private tokenCounter;

    // Array to track users for payouts
    address[] private allFarmers;
    mapping(address => bool) private isFarmer;

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
        uint256 premium,
        uint256 timestamp
    );

    event ClaimMadeEvent(
        address indexed farmer,
        uint256 indexed tokenId,
        uint256 payoutAmount,
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

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _usdcAddress) {
        owner = msg.sender;
        usdc = IERC20(_usdcAddress);
        tokenCounter = 1;

        // Set premium per policy token
        premium = 200 * 10**6; // 200 USDC per policy token
    }

    /**
     * @dev Farmers buy multiple policy tokens
     * @param _amount Number of policy tokens to buy
     */
    function buyPolicy(uint256 _amount) external returns (uint256[] memory tokenIds) {
        require(_amount > 0, "Amount must be greater than 0");
        
        uint256 totalPremium = premium * _amount;
        require(usdc.balanceOf(msg.sender) >= totalPremium, "Insufficient USDC");
        require(usdc.allowance(msg.sender, address(this)) >= totalPremium, "Allowance too low");

        require(usdc.transferFrom(msg.sender, address(this), totalPremium), "Transfer failed");

        tokenIds = new uint256[](_amount);

        // Add farmer to tracking if not already added
        if (!isFarmer[msg.sender]) {
            isFarmer[msg.sender] = true;
            allFarmers.push(msg.sender);
            emit FarmerAdded(msg.sender, block.timestamp);
        }

        // Create multiple policy tokens
        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = tokenCounter++;
            tokenIds[i] = tokenId;
            
            tokenOwner[tokenId] = msg.sender;
            farmerTokens[msg.sender].push(tokenId);

            policies[tokenId] = Policy({
                creationTimestamp: block.timestamp,
                expirationTimestamp: block.timestamp + 30 seconds,
                payoutAmount: premium * 2, // 2x payout per token
                locationHash: keccak256(abi.encodePacked(msg.sender, tokenId)),
                weatherData: 0,
                weatherDataFetched: false,
                payoutDone: false
            });

            emit PolicyBoughtEvent(msg.sender, tokenId, premium, block.timestamp);
        }

        riskPoolBalance += totalPremium;

        return tokenIds;
    }

    /**
     * @dev Manual claim function for a specific policy token
     * @param _tokenId The token ID to claim
     */
    function claim(uint256 _tokenId) external {
        Policy storage policy = policies[_tokenId];
        address policyHolder = tokenOwner[_tokenId];

        require(msg.sender == policyHolder, "Not token owner");
        require(policy.creationTimestamp != 0, "Policy not found");
        require(block.timestamp > policy.expirationTimestamp, "Crop season not over");
        require(policy.weatherDataFetched, "Weather data not available");
        require(!policy.payoutDone, "Already paid");
        require(checkChainLink(_tokenId), "Weather condition not met");
        require(policy.weatherData < 10, "Weather condition not met for payout");
        require(riskPoolBalance >= policy.payoutAmount, "Insufficient pool funds");

        // Execute payout
        require(usdc.transfer(policyHolder, policy.payoutAmount), "USDC payout failed");
        riskPoolBalance -= policy.payoutAmount;
        policy.payoutDone = true;

        // Remove token from farmer's list
        _removeTokenFromFarmer(policyHolder, _tokenId);

        emit ClaimMadeEvent(policyHolder, _tokenId, policy.payoutAmount, block.timestamp);
    }

    /**
     * @dev Claims all eligible policy tokens for the caller
     */
    function claimAll() external {
        uint256[] storage tokens = farmerTokens[msg.sender];
        require(tokens.length > 0, "No policies found");

        uint256 totalPayout = 0;
        uint256 successfulClaims = 0;

        // Process claims in reverse order to handle array modifications
        for (int256 i = int256(tokens.length) - 1; i >= 0; i--) {
            uint256 tokenId = tokens[uint256(i)];
            Policy storage policy = policies[tokenId];

            // Check if this token is eligible for claim
            if (!policy.payoutDone &&
                policy.weatherDataFetched &&
                block.timestamp > policy.expirationTimestamp &&
                checkChainLink(tokenId) &&
                policy.weatherData < 10 &&
                riskPoolBalance >= policy.payoutAmount) {
                
                totalPayout += policy.payoutAmount;
                riskPoolBalance -= policy.payoutAmount;
                policy.payoutDone = true;
                successfulClaims++;

                // Remove token from array (swap with last and pop)
                tokens[uint256(i)] = tokens[tokens.length - 1];
                tokens.pop();

                emit ClaimMadeEvent(msg.sender, tokenId, policy.payoutAmount, block.timestamp);
            }
        }

        require(successfulClaims > 0, "No eligible claims found");
        require(usdc.transfer(msg.sender, totalPayout), "USDC payout failed");

        // Clean up farmer if no tokens remain
        if (tokens.length == 0) {
            _removeFarmer(msg.sender);
        }
    }

    /**
     * @dev Removes a specific token from farmer's token list
     */
    function _removeTokenFromFarmer(address farmer, uint256 tokenId) internal {
        uint256[] storage tokens = farmerTokens[farmer];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
        
        // Clean up farmer if no tokens remain
        if (tokens.length == 0) {
            _removeFarmer(farmer);
        }
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
     * @dev Owner updates weather data for a policy
     */
    function updateWeatherData(uint256 _tokenId, uint256 _rainfall) external onlyOwner {
        Policy storage policy = policies[_tokenId];
        require(policy.creationTimestamp != 0, "Policy not found");
        require(!policy.weatherDataFetched, "Already fetched");
        policy.weatherData = _rainfall;
        policy.weatherDataFetched = true;
    }

    /**
     * @dev Batch update weather data for multiple policies
     */
    function batchUpdateWeatherData(uint256[] calldata _tokenIds, uint256[] calldata _rainfallData) external onlyOwner {
        require(_tokenIds.length == _rainfallData.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            Policy storage policy = policies[_tokenIds[i]];
            require(policy.creationTimestamp != 0, "Policy not found");
            require(!policy.weatherDataFetched, "Already fetched");
            policy.weatherData = _rainfallData[i];
            policy.weatherDataFetched = true;
        }
    }

    /**
     * @dev Mock chainlink check (replace with actual oracle integration)
     */
    function checkChainLink(uint256 _tokenId) internal view returns (bool conditionMet) {
        return ((block.timestamp + _tokenId) % 2) == 0;
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

    // ---------------- View Functions ----------------

    function getFarmerTokens(address _farmer) external view returns (uint256[] memory) {
        return farmerTokens[_farmer];
    }

    function getClaimableTokens(address _farmer) external view returns (uint256[] memory claimableTokens, uint256 totalClaimAmount) {
        uint256[] memory tokens = farmerTokens[_farmer];
        uint256[] memory tempClaimable = new uint256[](tokens.length);
        uint256 claimableCount = 0;
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            Policy storage policy = policies[tokenId];

            if (!policy.payoutDone &&
                policy.weatherDataFetched &&
                block.timestamp > policy.expirationTimestamp &&
                checkChainLink(tokenId) &&
                policy.weatherData < 10) {
                
                tempClaimable[claimableCount] = tokenId;
                totalAmount += policy.payoutAmount;
                claimableCount++;
            }
        }

        claimableTokens = new uint256[](claimableCount);
        for (uint256 i = 0; i < claimableCount; i++) {
            claimableTokens[i] = tempClaimable[i];
        }

        return (claimableTokens, totalAmount);
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

    function getUserInvestment(address _investor) external view returns (uint256) {
        return investorShares[_investor];
    }

    function getUSDCAddress() external view returns (address) {
        return address(usdc);
    }

    function getAllFarmers() external view returns (address[] memory) {
        return allFarmers;
    }
}
