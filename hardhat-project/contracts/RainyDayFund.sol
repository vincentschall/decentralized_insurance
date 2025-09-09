// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

contract RainyDayFund {
    IERC20 public immutable usdc;
    address public owner;
    
    // Risk pool tracking
    uint256 public riskPoolBalance;
    uint256 public totalInvestorFunds;
    mapping(address => uint256) public investorShares;
    
    // Policy tracking
    uint256 private tokenCounter;

    // Season tracking
    uint256 public seasonOverTimeStamp = 60 days;
    uint256 constant timeUnit = 30 days;

    // Policy structure for minimal data storage
    struct Policy {
        uint256 creationTimestamp;
        uint256 payoutAmount;
        uint256 weatherData;
        bool weatherDataFetched;
        bool payoutDone;
    }
    mapping(uint256 => Policy) public policies;
    mapping(uint256 => address) public tokenOwner;
    mapping(address => uint256[]) public farmerTokens;
    
    // Weather oracle placeholder
    AggregatorV3Interface internal weatherFeed;
    bool public useChainlinkOracle = false;
    
    // Events
    event PolicyBought(address indexed farmer, uint256[] tokenIds, uint256 totalPremium);
    event ClaimMade(address indexed farmer, uint256 totalPayout, uint256 tokenCount);
    event InvestmentMade(address indexed investor, uint256 amount);
    event InvestmentWithdrawn(address indexed investor, uint256 amount);
    event WeatherDataUpdated(uint256[] tokenIds, uint256[] weatherData);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _usdcAddress) {
        owner = msg.sender;
        usdc = IERC20(_usdcAddress);
        tokenCounter = 1;
    }

    /**
     * @dev Calculate current premium based on supply/demand
     * TODO: Implement actual supply/demand pricing algorithm
     */
    function getCurrentPremium() public pure returns (uint256) {
        // Placeholder: Return base premium of 200 USDC
        // Future: Calculate based on pool utilization, recent claims, etc.
        return 200 * 10**6; // 200 USDC
    }

    /**
     * @dev Buy multiple insurance policies
     */
    function buyPolicy(uint256 _amount) external returns (uint256[] memory tokenIds) {
        require(_amount > 0, "Amount must be > 0");
        require(block.timestamp < (seasonOverTimeStamp - timeUnit), "Policy not available anymore");
        
        uint256 premium = getCurrentPremium();
        uint256 totalPremium = premium * _amount;
        
        require(usdc.transferFrom(msg.sender, address(this), totalPremium), "Transfer failed");

        tokenIds = new uint256[](_amount);

        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = tokenCounter++;
            tokenIds[i] = tokenId;
            
            tokenOwner[tokenId] = msg.sender;
            farmerTokens[msg.sender].push(tokenId);

            policies[tokenId] = Policy({
                creationTimestamp: block.timestamp,
                payoutAmount: premium * 2, // 2x payout -> placeholder
                weatherData: 0,
                weatherDataFetched: false,
                payoutDone: false
            });
        }

        riskPoolBalance += totalPremium;
        emit PolicyBought(msg.sender, tokenIds, totalPremium);
        
        return tokenIds;
    }

    /**
     * @dev Claim all eligible policies for the caller
     */
    function claimAll() external {
        uint256[] storage tokens = farmerTokens[msg.sender];
        require(tokens.length > 0, "No policies found");

        uint256 totalPayout = 0;
        uint256 claimedCount = 0;

        // Process claims in reverse order for safe array modification
        for (int256 i = int256(tokens.length) - 1; i >= 0; i--) {
            uint256 tokenId = tokens[uint256(i)];
            Policy storage policy = policies[tokenId];

            if (_isPolicyClaimable(tokenId)) {
                totalPayout += policy.payoutAmount;
                riskPoolBalance -= policy.payoutAmount;
                policy.payoutDone = true;
                claimedCount++;

                // Remove token from array
                tokens[uint256(i)] = tokens[tokens.length - 1];
                tokens.pop();
            }
        }

        require(claimedCount > 0, "No eligible claims");
        require(totalPayout <= riskPoolBalance, "Insufficient pool funds");
        require(usdc.transfer(msg.sender, totalPayout), "Payout failed");

        emit ClaimMade(msg.sender, totalPayout, claimedCount);
    }

    /**
     * @dev Check if a policy is claimable
     */
    function _isPolicyClaimable(uint256 tokenId) internal view returns (bool) {
        Policy storage policy = policies[tokenId];
        return (!policy.payoutDone &&
                policy.weatherDataFetched &&
                block.timestamp > seasonOverTimeStamp &&
                block.timestamp < (seasonOverTimeStamp + timeUnit) &&
                _getWeatherCondition(tokenId) &&
                policy.weatherData < 10);
    }

    /**
     * @dev Weather condition check - placeholder for Chainlink integration
     */
    function _getWeatherCondition(uint256 tokenId) internal view returns (bool) {
        if (useChainlinkOracle && address(weatherFeed) != address(0)) {
            // TODO: Implement actual Chainlink weather data fetching
            // (, int256 price,,,) = weatherFeed.latestRoundData();
            // return uint256(price) < 10;
            return true; // Placeholder
        } else {
            // Mock condition for testing
            return ((block.timestamp + tokenId) % 2) == 0;
        }
    }

    /**
     * @dev Owner updates weather data (for testing phase)
     */
    function updateWeatherData(uint256[] calldata tokenIds, uint256[] calldata weatherData) external onlyOwner {
        require(tokenIds.length == weatherData.length, "Array length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            Policy storage policy = policies[tokenIds[i]];
            require(policy.creationTimestamp != 0, "Policy not found");
            policy.weatherData = weatherData[i];
            policy.weatherDataFetched = true;
        }
        
        emit WeatherDataUpdated(tokenIds, weatherData);
    }

    /**
     * @dev Set Chainlink oracle address (for production)
     */
    function setWeatherOracle(address _oracleAddress, bool _useChainlink) external onlyOwner {
        weatherFeed = AggregatorV3Interface(_oracleAddress);
        useChainlinkOracle = _useChainlink;
    }

    // ================== INVESTOR FUNCTIONS ==================

    function invest(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        investorShares[msg.sender] += amount;
        totalInvestorFunds += amount;
        riskPoolBalance += amount;

        emit InvestmentMade(msg.sender, amount);
    }

    /**
     * @dev Withdraw funds from the risk pool after the season is over and 60 days have passed until 90 days after season end
     */
    function withdraw() external {
        require(
                block.timestamp > (seasonOverTimeStamp + 2 * timeUnit) &&
                block.timestamp < (seasonOverTimeStamp + 3 * timeUnit) );

        uint256 shareAmount = investorShares[msg.sender]; 
        uint256 withdrawAmount = (shareAmount * riskPoolBalance) / totalInvestorFunds;
        
        investorShares[msg.sender] -= 0;
        totalInvestorFunds -= shareAmount;
        riskPoolBalance -= withdrawAmount;

        require(usdc.transfer(msg.sender, withdrawAmount), "Withdrawal failed");
        emit InvestmentWithdrawn(msg.sender, withdrawAmount);
    }

    // ================== VIEW FUNCTIONS ==================

    function getFarmerTokens(address farmer) external view returns (uint256[] memory) {
        return farmerTokens[farmer];
    }

    function getClaimableInfo(address farmer) external view returns (uint256[] memory claimableTokens, uint256 totalClaimAmount) {
        uint256[] memory tokens = farmerTokens[farmer];
        uint256[] memory tempClaimable = new uint256[](tokens.length);
        uint256 claimableCount = 0;
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            if (_isPolicyClaimable(tokenId)) {
                tempClaimable[claimableCount] = tokenId;
                totalAmount += policies[tokenId].payoutAmount;
                claimableCount++;
            }
        }

        claimableTokens = new uint256[](claimableCount);
        for (uint256 i = 0; i < claimableCount; i++) {
            claimableTokens[i] = tempClaimable[i];
        }

        return (claimableTokens, totalAmount);
    }

    function getTotalPolicies() external view returns (uint256) {
        return tokenCounter - 1;
    }

    function getContractBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function getUserInvestment(address investor) external view returns (uint256) {
        return investorShares[investor];
    }
}
