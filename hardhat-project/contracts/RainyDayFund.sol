// SPDX-License-Identifier: MIT// SPDX-License-Identifier: MIT
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

    // Total risk pool balance in USDC
    uint256 public riskPoolBalance;

    // Token counter for unique policy IDs
    uint256 private tokenCounter;

    // Policy types
    enum PolicyType {
        BASIC,      // 100 USDC premium
        STANDARD,   // 250 USDC premium  
        PREMIUM     // 500 USDC premium
    }

    // Policy pricing (USDC - 6 decimals)
    mapping(PolicyType => uint256) public premiums;

    // Mapping for policies
    struct Policy {
        uint256 creationTimestamp;
        uint256 expirationTimestamp;
        uint256 payoutAmount;
        bytes32 locationHash;        // hashed location
        uint256 weatherData;         // fetched weather data (e.g., rainfall)
        bool weatherDataFetched;     // weather data is available
        bool payoutDone;             // payout already occurred
    }
    mapping(address => Policy) public policies;

    // Token ownership
    mapping(uint256 => address) public tokenOwner; // tokenId => owner
    mapping(address => uint256[]) public farmerTokens; // farmer => tokenIds

    // Investment tracking
    mapping(address => uint256) public totalInvestments; // investor => total

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

        // Save policy data
        policies[msg.sender] = Policy({
            creationTimestamp: block.timestamp,
            expirationTimestamp: block.timestamp + 30 seconds, // example duration
            payoutAmount: premiumAmount * 2, // e.g., payout aims to double
            locationHash: keccak256(abi.encodePacked("example-location")), // placeholder
            weatherData: 0,
            weatherDataFetched: false,
            payoutDone: false
        });

        riskPoolBalance += premiumAmount;

        emit PolicyBoughtEvent(msg.sender, tokenId, _policyType, premiumAmount, block.timestamp);

        return tokenId;
    }

    /**
     * @dev Dummy placeholder for oracle/weather validation check.
     */
    function checkChainLink(address _policyHolder) internal view returns (bool conditionMet) {
        // Placeholder: implement actual oracle check or replace with real logic
        // For now, simulate with a 50% chance
        return (block.timestamp % 2) == 0;
    }

    /**
     * @dev External function to update weather data after fetching from oracle
     */
    function updateWeatherData(address _policyHolder, uint256 _rainfall) external {
        // Only owner or authorized can call in real implementation
        Policy storage policy = policies[_policyHolder];
        require(policy.creationTimestamp != 0, "Policy not found");
        require(!policy.weatherDataFetched, "Already fetched");
        policy.weatherData = _rainfall;
        policy.weatherDataFetched = true;
    }

    /**
     * @dev Main payout logic
     */
    function payout(address _policyHolder) external {
        Policy storage policy = policies[_policyHolder];

        require(block.timestamp > policy.expirationTimestamp, "Crop season not over");
        require(policy.weatherDataFetched, "Weather data not available");
        require(!policy.payoutDone, "Already paid");
        require(checkChainLink(_policyHolder), "Weather condition not met");
        require(riskPoolBalance >= policy.payoutAmount, "Insufficient pool funds");

        // Example threshold: payout if rainfall below 10mm
        uint256 rainfallThreshold = 10;
        if (policy.weatherData < rainfallThreshold) {
            // Transfer USDC payout to farmer
            require(usdc.transfer(_policyHolder, policy.payoutAmount), "USDC payout failed");
            riskPoolBalance -= policy.payoutAmount;
            policy.payoutDone = true;
        }
        // else, no payout (can add alternative logic)
    }

    /**
     * @dev Allows investors to invest USDC in the risk pool
     * @param _amount Amount of USDC to invest (with 6 decimals)
     */
    function invest(uint256 _amount) external {
        require(_amount > 0, "Investment amount must be greater than 0");
        
        // Check user has enough USDC balance
        require(usdc.balanceOf(msg.sender) >= _amount, "Insufficient USDC balance");
        
        // Check user has approved enough USDC for this contract
        require(usdc.allowance(msg.sender, address(this)) >= _amount, "Insufficient USDC allowance");
        
        // Transfer USDC from user to contract
        require(usdc.transferFrom(msg.sender, address(this), _amount), "USDC transfer failed");
        
        // Track investment
        totalInvestments[msg.sender] += _amount;
        
        // Add to risk pool
        riskPoolBalance += _amount;
        
        // Emit event
        emit InvestmentMadeEvent(
            msg.sender,
            _amount,
            block.timestamp
        );
    }
    
    /**
     * @dev Get all token IDs owned by a farmer
     * @param _farmer Address of the farmer
     * @return Array of token IDs
     */
    function getFarmerTokens(address _farmer) external view returns (uint256[] memory) {
        return farmerTokens[_farmer];
    }
    
    /**
     * @dev Get policy pricing information
     * @param _policyType Policy type to query
     * @return premium amount in USDC (6 decimals)
     */
    function getPolicyPricing(PolicyType _policyType) 
        external 
        view 
        validPolicyType(_policyType) 
        returns (uint256 premium) 
    {
        return premiums[_policyType];
    }
    
    /**
     * @dev Check if a token exists
     * @param _tokenId Token ID to check
     * @return bool indicating if token exists
     */
    function tokenExists(uint256 _tokenId) external view returns (bool) {
        return tokenOwner[_tokenId] != address(0);
    }
    
    /**
     * @dev Get owner of a policy token
     * @param _tokenId Token ID to query
     * @return Address of the token owner
     */
    function ownerOf(uint256 _tokenId) external view returns (address) {
        require(tokenOwner[_tokenId] != address(0), "Token does not exist");
        return tokenOwner[_tokenId];
    }
    
    /**
     * @dev Get total number of policies (total tokens minted)
     * @return Number of policies
     */
    function getTotalPolicies() external view returns (uint256) {
        return tokenCounter - 1; // Subtract 1 because we start from 1
    }
    
    /**
     * @dev Get contract's USDC balance
     * @return Contract's USDC balance
     */
    function getContractUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    /**
     * @dev Get user's total investments
     * @param _investor Investor address
     * @return Total amount invested by user
     */
    function getUserInvestments(address _investor) external view returns (uint256) {
        return totalInvestments[_investor];
    }
    
    /**
     * @dev Get USDC contract address
     * @return USDC contract address
     */
    function getUSDCAddress() external view returns (address) {
        return address(usdc);
    }
}
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
    
    // Total risk pool balance in USDC
    uint256 public riskPoolBalance;
    
    // Token counter for unique policy NFTs
    uint256 private tokenCounter;
    
    // Policy types
    enum PolicyType {
        BASIC,      // 100 USDC premium
        STANDARD,   // 250 USDC premium  
        PREMIUM     // 500 USDC premium
    }
    
    // Policy pricing (in USDC - 6 decimals)
    mapping(PolicyType => uint256) public premiums;
    
    // Token ownership
    mapping(uint256 => address) public tokenOwner; // tokenId => owner
    mapping(address => uint256[]) public farmerTokens; // farmer => tokenIds
    
    // Investment tracking
    mapping(address => uint256) public totalInvestments; // investor => total amount invested
    
    // Events
    event PolicyBoughtEvent(
        address indexed farmer,
        uint256 indexed tokenId,
        PolicyType indexed policyType,
        uint256 premium,
        uint256 timestamp
    );
    
    event InvestmentMadeEvent(
        address indexed investor,
        uint256 amount,
        uint256 timestamp
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validPolicyType(PolicyType _policyType) {
        require(uint8(_policyType) <= 2, "Invalid policy type");
        _;
    }
    
    constructor(address _usdcAddress) {
        owner = msg.sender;
        usdc = IERC20(_usdcAddress);
        tokenCounter = 1; // Start token IDs from 1
        
        // Set policy premiums (USDC has 6 decimals)
        premiums[PolicyType.BASIC] = 100 * 10**6;      // 100 USDC
        premiums[PolicyType.STANDARD] = 250 * 10**6;   // 250 USDC
        premiums[PolicyType.PREMIUM] = 500 * 10**6;    // 500 USDC
    }
    
    /**
     * @dev Allows farmers to buy insurance policies with USDC and receive a policy token as receipt
     * @param _policyType The type of policy to purchase (0=BASIC, 1=STANDARD, 2=PREMIUM)
     */
    function buyPolicy(PolicyType _policyType) 
        external 
        validPolicyType(_policyType) 
        returns (uint256 tokenId)
    {
        uint256 requiredPremium = premiums[_policyType];
        
        // Check user has enough USDC balance
        require(usdc.balanceOf(msg.sender) >= requiredPremium, "Insufficient USDC balance");
        
        // Check user has approved enough USDC for this contract
        require(usdc.allowance(msg.sender, address(this)) >= requiredPremium, "Insufficient USDC allowance");
        
        // Transfer USDC from user to contract
        require(usdc.transferFrom(msg.sender, address(this), requiredPremium), "USDC transfer failed");
        
        // Generate new token ID
        tokenId = tokenCounter;
        tokenCounter++;
        
        // Store token ownership
        tokenOwner[tokenId] = msg.sender;
        farmerTokens[msg.sender].push(tokenId);
        
        // Add premium to risk pool
        riskPoolBalance += requiredPremium;
        
        // Emit event
        emit PolicyBoughtEvent(
            msg.sender,
            tokenId,
            _policyType,
            requiredPremium,
            block.timestamp
        );
        
        return tokenId;
    }
    
    /**
     * @dev Allows investors to invest USDC in the risk pool
     * @param _amount Amount of USDC to invest (with 6 decimals)
     */
    function invest(uint256 _amount) external {
        require(_amount > 0, "Investment amount must be greater than 0");
        
        // Check user has enough USDC balance
        require(usdc.balanceOf(msg.sender) >= _amount, "Insufficient USDC balance");
        
        // Check user has approved enough USDC for this contract
        require(usdc.allowance(msg.sender, address(this)) >= _amount, "Insufficient USDC allowance");
        
        // Transfer USDC from user to contract
        require(usdc.transferFrom(msg.sender, address(this), _amount), "USDC transfer failed");
        
        // Track investment
        totalInvestments[msg.sender] += _amount;
        
        // Add to risk pool
        riskPoolBalance += _amount;
        
        // Emit event
        emit InvestmentMadeEvent(
            msg.sender,
            _amount,
            block.timestamp
        );
    }
    
    /**
     * @dev Get all token IDs owned by a farmer
     * @param _farmer Address of the farmer
     * @return Array of token IDs
     */
    function getFarmerTokens(address _farmer) external view returns (uint256[] memory) {
        return farmerTokens[_farmer];
    }
    
    /**
     * @dev Get policy pricing information
     * @param _policyType Policy type to query
     * @return premium amount in USDC (6 decimals)
     */
    function getPolicyPricing(PolicyType _policyType) 
        external 
        view 
        validPolicyType(_policyType) 
        returns (uint256 premium) 
    {
        return premiums[_policyType];
    }
    
    /**
     * @dev Check if a token exists
     * @param _tokenId Token ID to check
     * @return bool indicating if token exists
     */
    function tokenExists(uint256 _tokenId) external view returns (bool) {
        return tokenOwner[_tokenId] != address(0);
    }
    
    /**
     * @dev Get owner of a policy token
     * @param _tokenId Token ID to query
     * @return Address of the token owner
     */
    function ownerOf(uint256 _tokenId) external view returns (address) {
        require(tokenOwner[_tokenId] != address(0), "Token does not exist");
        return tokenOwner[_tokenId];
    }
    
    /**
     * @dev Get total number of policies (total tokens minted)
     * @return Number of policies
     */
    function getTotalPolicies() external view returns (uint256) {
        return tokenCounter - 1; // Subtract 1 because we start from 1
    }
    
    /**
     * @dev Get contract's USDC balance
     * @return Contract's USDC balance
     */
    function getContractUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    /**
     * @dev Get user's total investments
     * @param _investor Investor address
     * @return Total amount invested by user
     */
    function getUserInvestments(address _investor) external view returns (uint256) {
        return totalInvestments[_investor];
    }
    
    /**
     * @dev Get USDC contract address
     * @return USDC contract address
     */
    function getUSDCAddress() external view returns (address) {
        return address(usdc);
    }
}
