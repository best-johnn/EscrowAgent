# EscrowAgent

A Clarity smart contract that implements an address reputation system for escrow service provider trustworthiness scoring on the Stacks blockchain.

## Overview

EscrowAgent is a comprehensive reputation management system designed to track and evaluate the trustworthiness of escrow service providers. The contract maintains detailed reputation scores based on transaction history, dispute resolution outcomes, and community feedback, enabling clients to make informed decisions when selecting escrow agents.

## Features

- **Agent Registration**: Escrow agents can register themselves with an initial reputation score
- **Transaction Management**: Create, complete, and dispute escrow transactions
- **Reputation Scoring**: Dynamic scoring system based on transaction outcomes (0-1000 scale)
- **Client Rating System**: 5-star rating system with comments for completed transactions
- **Agent Verification**: Contract owner can verify legitimate agents
- **Success Rate Tracking**: Calculate and monitor agent performance metrics
- **Trustworthiness Assessment**: Automated evaluation of agent reliability
- **Agent Status Management**: Activate/deactivate agents as needed

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Epoch**: 2.5
- **Reputation Scale**: 0-1000 points
- **Initial Score**: 500 points
- **Trustworthy Threshold**: 700 points
- **Rating Scale**: 1-5 stars

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.0+
- [Node.js](https://nodejs.org/) v16+
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd EscrowAgent
```

2. Navigate to the contract directory:
```bash
cd EscrowAgent_contract
```

3. Install dependencies:
```bash
npm install
```

4. Run tests:
```bash
npm test
```

## Usage Examples

### Register as an Escrow Agent

```clarity
;; Register the calling address as an escrow agent
(contract-call? .EscrowAgent register-agent)
```

### Create an Escrow Transaction

```clarity
;; Create a transaction with a specific agent for 1000 STX
(contract-call? .EscrowAgent create-transaction 'SP1234...AGENT-ADDRESS u1000)
```

### Complete a Transaction

```clarity
;; Complete transaction with ID 1
(contract-call? .EscrowAgent complete-transaction u1)
```

### Rate an Agent

```clarity
;; Rate an agent 5 stars after a completed transaction
(contract-call? .EscrowAgent rate-agent 'SP1234...AGENT-ADDRESS u1 u5 u"Excellent service!")
```

### Check Agent Reputation

```clarity
;; Get reputation details for an agent
(contract-call? .EscrowAgent get-agent-reputation 'SP1234...AGENT-ADDRESS)
```

## Contract Functions

### Public Functions

#### Agent Management

- **`register-agent()`**
  - Registers the caller as a new escrow agent
  - Sets initial reputation score to 500
  - Returns: `(response bool uint)`

- **`verify-agent(agent: principal)`** (Owner only)
  - Verifies an agent's legitimacy
  - Only callable by contract owner
  - Returns: `(response bool uint)`

- **`deactivate-agent(agent: principal)`** (Owner only)
  - Deactivates an agent
  - Only callable by contract owner
  - Returns: `(response bool uint)`

#### Transaction Management

- **`create-transaction(agent: principal, amount: uint)`**
  - Creates a new escrow transaction
  - Returns transaction ID
  - Returns: `(response uint uint)`

- **`complete-transaction(transaction-id: uint)`**
  - Marks transaction as completed successfully
  - Updates agent reputation positively
  - Callable by agent or client
  - Returns: `(response bool uint)`

- **`dispute-transaction(transaction-id: uint)`**
  - Reports a transaction as disputed
  - Updates agent reputation negatively
  - Only callable by the client
  - Returns: `(response bool uint)`

#### Rating System

- **`rate-agent(agent: principal, transaction-id: uint, rating: uint, comment: string-utf8)`**
  - Submit a 1-5 star rating for an agent
  - Only for completed transactions
  - One rating per transaction per client
  - Returns: `(response bool uint)`

### Read-Only Functions

- **`get-agent-reputation(agent: principal)`**
  - Returns complete reputation data for an agent
  - Includes score, transaction counts, volume, etc.

- **`get-transaction(transaction-id: uint)`**
  - Returns transaction details by ID

- **`get-agent-verification(agent: principal)`**
  - Returns verification status and details

- **`get-client-rating(client: principal, agent: principal, transaction-id: uint)`**
  - Returns specific rating given by a client

- **`get-agent-success-rate(agent: principal)`**
  - Calculates success rate as percentage (0-100)

- **`is-agent-trustworthy(agent: principal)`**
  - Returns true if agent score >= 700 and is active

## Deployment Guide

### Local Development

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy contract:
```clarity
::deploy_contracts
```

3. Test functions:
```clarity
(contract-call? .EscrowAgent register-agent)
```

### Testnet Deployment

1. Update `settings/Testnet.toml` with your configuration

2. Deploy to testnet:
```bash
clarinet deploy --testnet
```

### Mainnet Deployment

1. Update `settings/Mainnet.toml` with production settings

2. Deploy to mainnet:
```bash
clarinet deploy --mainnet
```

## Reputation Scoring Algorithm

The reputation system uses a dynamic scoring algorithm:

- **Initial Score**: 500 points
- **Successful Transaction**: +10 points (max 1000)
- **Disputed Transaction**: -20 points (min 0)
- **High Success Rate Bonus**: +5 points (>80% success rate)
- **Low Success Rate Penalty**: -10 points (<20% success rate)

### Trustworthiness Levels

- **Highly Trusted**: 900-1000 points
- **Trusted**: 700-899 points
- **Neutral**: 300-699 points
- **Caution**: 100-299 points
- **Untrusted**: 0-99 points

## Security Considerations

### Access Controls

- Agent registration is open to all addresses
- Transaction completion requires authorization from agent or client
- Disputes can only be filed by transaction clients
- Agent verification/deactivation restricted to contract owner
- Ratings limited to one per transaction per client

### Data Integrity

- All reputation changes are transparent and auditable
- Transaction history is immutable once recorded
- Rating system prevents duplicate submissions
- Score calculations use safe arithmetic operations

### Best Practices

1. **Verify Agent Status**: Always check `is-agent-trustworthy` before engaging
2. **Review Transaction History**: Examine success rates and dispute patterns
3. **Check Verification Status**: Prefer verified agents for high-value transactions
4. **Monitor Reputation Changes**: Track score trends over time
5. **Use Appropriate Amounts**: Start with smaller transactions for new agents

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-NOT-AUTHORIZED | Unauthorized action attempted |
| 101 | ERR-AGENT-NOT-FOUND | Agent not registered |
| 102 | ERR-INVALID-SCORE | Invalid reputation score |
| 103 | ERR-TRANSACTION-NOT-FOUND | Transaction ID does not exist |
| 104 | ERR-ALREADY-RATED | Rating already submitted |
| 105 | ERR-INVALID-RATING | Rating outside 1-5 range |
| 106 | ERR-AGENT-ALREADY-EXISTS | Agent already registered |

## Testing

Run the test suite:

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:report

# Watch mode for development
npm run test:watch
```

## License

This project is licensed under the ISC License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Support

For questions, issues, or feature requests, please open an issue in the project repository.