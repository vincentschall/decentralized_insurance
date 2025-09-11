// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

contract RainyDayFund is ERC4626, Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;

    uint256 public currentSeasonId;
    uint256 public seasonOverTimeStamp;
    uint256 constant timeUnit = 1 minutes; // short for demo

    AggregatorV3Interface public weatherFeed;

    struct SeasonPolicy {
        uint256 creationTimestamp;
        uint256 payoutAmount;
        uint256 premium;
        uint256 totalPoliciesSold;
        bool payoutEnabled;
        bool seasonActive;
        ERC20 policyToken;
    }

    mapping(uint256 => SeasonPolicy) public seasonPolicies;

    event PolicyBought(address indexed farmer, uint256 seasonId, uint256 amount, uint256 totalPremium);
    event ClaimMade(address indexed farmer, uint256 seasonId, uint256 amount, uint256 totalPayout);
    event InvestmentMade(address indexed investor, uint256 amount);
    event InvestmentWithdrawn(address indexed investor, uint256 amount);
    event WeatherDataUpdated(uint256 seasonId, uint256 weatherData);
    event NewSeasonStarted(uint256 seasonId, uint256 premium, uint256 payoutAmount);

    constructor(address _usdcAddress, address _weatherOracle)
        ERC4626(IERC20Metadata(_usdcAddress))
        ERC20("RainyDay Investor Shares", "RDIS")
        Ownable(msg.sender)
    {
        require(_usdcAddress != address(0), "USDC address zero");
        usdc = IERC20(_usdcAddress);

        require(_weatherOracle != address(0), "Weather oracle zero");
        weatherFeed = AggregatorV3Interface(_weatherOracle);

        currentSeasonId = 1;
        _initializeSeason(currentSeasonId);
        seasonOverTimeStamp = block.timestamp + 2 * timeUnit; // short demo
    }

    function _initializeSeason(uint256 seasonId) internal {
        uint256 premium = 200 * 10**6; // 200 USDC

        SeasonPolicyToken policyToken = new SeasonPolicyToken(
            string(abi.encodePacked("RainyDay Policy Season ", _toString(seasonId))),
            string(abi.encodePacked("RDP", _toString(seasonId))),
            address(this)
        );

        seasonPolicies[seasonId] = SeasonPolicy({
            creationTimestamp: block.timestamp,
            payoutAmount: premium * 2,
            premium: premium,
            totalPoliciesSold: 0,
            payoutEnabled: true,
            seasonActive: true,
            policyToken: policyToken
        });

        emit NewSeasonStarted(seasonId, premium, premium * 2);
    }

    function startNewSeason() external onlyOwner {
        seasonPolicies[currentSeasonId].seasonActive = false;
        currentSeasonId++;
        seasonOverTimeStamp = block.timestamp + 2 * timeUnit;
        _initializeSeason(currentSeasonId);
    }

    function buyPolicy(uint256 _amount) external nonReentrant returns (uint256 seasonId) {
        require(_amount > 0, "Amount > 0");
        require(block.timestamp < seasonOverTimeStamp - timeUnit, "Policy sales ended");

        SeasonPolicy storage policy = seasonPolicies[currentSeasonId];
        require(policy.seasonActive, "Season not active");

        uint256 totalPremium = policy.premium * _amount;
        require(usdc.transferFrom(msg.sender, address(this), totalPremium), "Transfer failed");

        SeasonPolicyToken(address(policy.policyToken)).mint(msg.sender, _amount);
        policy.totalPoliciesSold += _amount;

        emit PolicyBought(msg.sender, currentSeasonId, _amount, totalPremium);
        return currentSeasonId;
    }

    function claimPolicies(uint256 seasonId, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount > 0");
        require(_isPolicyClaimable(seasonId), "Policy not claimable");

        SeasonPolicy storage policy = seasonPolicies[seasonId];
        SeasonPolicyToken token = SeasonPolicyToken(address(policy.policyToken));
        require(token.balanceOf(msg.sender) >= amount, "Insufficient policy tokens");

        uint256 totalPayout = policy.payoutAmount * amount;
        require(usdc.balanceOf(address(this)) >= totalPayout, "Insufficient funds");

        token.burnFrom(msg.sender, amount);
        require(usdc.transfer(msg.sender, totalPayout), "Payout failed");

        emit ClaimMade(msg.sender, seasonId, amount, totalPayout);
    }

    function _isPolicyClaimable(uint256 seasonId) internal view returns (bool) {
        SeasonPolicy storage policy = seasonPolicies[seasonId];
        if (!policy.seasonActive && policy.payoutEnabled) {
            (,int256 weather,) = getWeatherData();
            return uint256(weather) < 10;
        }
        return false;
    }

    function getWeatherData() public view returns (uint80 roundId, int256 weather, uint256 timestamp) {
        (roundId, weather,,timestamp,) = weatherFeed.latestRoundData();
    }

    // ERC4626 investment logic
    function invest(uint256 assets) external nonReentrant {
        require(assets > 0, "Amount > 0");
        deposit(assets, msg.sender);
        emit InvestmentMade(msg.sender, assets);
    }

    function redeemShares(uint256 shares) external nonReentrant {
        require(_isWithdrawalPeriodActive(), "Withdrawal period not active");
        uint256 assets = redeem(shares, msg.sender, msg.sender);
        emit InvestmentWithdrawn(msg.sender, assets);
    }

    function _isWithdrawalPeriodActive() internal view returns (bool) {
        return block.timestamp > seasonOverTimeStamp + timeUnit &&
               block.timestamp < seasonOverTimeStamp + 2 * timeUnit;
    }

    function totalAssets() public view override returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    // minimal utility
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) { digits--; buffer[digits] = bytes1(uint8(48 + value % 10)); value /= 10; }
        return string(buffer);
    }
}

contract SeasonPolicyToken is ERC20 {
    address public immutable rainyDayFund;
    modifier onlyRainyDayFund() { require(msg.sender == rainyDayFund, "Only fund"); _; }

    constructor(string memory name, string memory symbol, address _fund) ERC20(name, symbol) {
        rainyDayFund = _fund;
    }

    function mint(address to, uint256 amount) external onlyRainyDayFund { _mint(to, amount); }
    function burnFrom(address from, uint256 amount) external onlyRainyDayFund { _burn(from, amount); }
}
