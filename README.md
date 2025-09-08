# decentralised (weather) insurance

Group project @University of Basel for The Blockchain Challenge.

## Execution

Install: npm, node, tailwindcss, metamask

Run frontend with `npm run dev`

Hardhat: run `npx hardhat compile`.
test: `npx hardhat test`
demo script: `npx hardhat run scripts/demo-rainy-day-fund.ts`
deploy via ignition: `npx hardhat ignition deploy ignition/modules/RainyDayFund.ts --network hardhatOp`

## Roadmap

- [x] basic frontend with buttons
- [x] metamask integration into frontend
- [ ] smart contract
- [ ] deploying and calling smart contract, transactions
- [ ] backend: calling smart contract payout
- [ ] smart contract: getting data via chainlink, checking condition
- [ ] riskpool, accounting, payout
