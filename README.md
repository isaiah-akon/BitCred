# BitCred - Bitcoin-Native Reputation Protocol

A revolutionary Bitcoin Layer-2 protocol that transforms digital interactions through verifiable reputation mechanics built on Stacks blockchain infrastructure.

## Overview

BitCred establishes the first comprehensive reputation economy native to Bitcoin's ecosystem. By leveraging Stacks' smart contract capabilities, this protocol creates immutable credential systems where reputation becomes programmable money. Users earn credibility through verified actions, building portable trust scores that unlock economic opportunities across Bitcoin-powered applications.

## Features

### 🔐 Decentralized Identity & Reputation

- **Staking-Based Identity Creation**: Users stake STX tokens to create verified identities
- **Dynamic Reputation Scoring**: Multi-factor reputation calculation including base score, stake amount, activity count, and verification level
- **Time-Based Decay**: Automatic reputation decay to ensure active participation
- **Anti-Gaming Mechanisms**: Daily activity limits and verification requirements

### 🏛️ Governance System

- **Proposal Creation**: Community-driven protocol improvements and parameter adjustments
- **Weighted Voting**: Reputation-based voting power for fair governance
- **Action Types**: Support for multiplier updates, governance changes, emergency actions, and protocol upgrades

### 🤝 Peer Attestation Network

- **Cross-Application Attestations**: Users can attest to others' reputation across different applications
- **Expiring Attestations**: Time-limited attestations with configurable durations
- **Impact Validation**: Attestation impact limited by attester's own reputation

### 📊 Advanced Analytics

- **Reputation Profiles**: Comprehensive user reputation data with decay calculations
- **Protocol Statistics**: Real-time insights into total staked amounts and active proposals
- **Verification Levels**: Tiered verification system (Basic, Verified, Premium)

## Smart Contract Architecture

### Core Data Structures

```clarity
;; Identity Registry
(define-map identities
  { owner: principal }
  {
    did: (string-ascii 50),
    reputation-score: uint,
    weighted-score: uint,
    stake-amount: uint,
    created-at: uint,
    last-updated: uint,
    last-decay: uint,
    activity-count: uint,
    verification-level: uint
  }
)
```

### Key Functions

- **`create-identity-with-stake`**: Initialize user identity with STX stake
- **`update-reputation-secure`**: Update reputation with anti-gaming protections
- **`create-attestation`**: Create peer attestations with impact validation
- **`create-proposal`**: Submit governance proposals
- **`vote-on-proposal`**: Vote on governance proposals with weighted voting

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) >= 2.0
- [Node.js](https://nodejs.org/) >= 18
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd BitCred
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Check contract syntax**

   ```bash
   clarinet check
   ```

### Development

#### Running Tests

Run the complete test suite:

```bash
npm test
```

Generate coverage and cost reports:

```bash
npm run test:report
```

Watch mode for continuous testing:

```bash
npm run test:watch
```

#### Contract Validation

Check contract syntax and type safety:

```bash
clarinet check
```

#### Development Environment

Start a local Stacks devnet:

```bash
clarinet devnet start
```

The devnet configuration is defined in `settings/Devnet.toml` with pre-funded test accounts.

## Protocol Configuration

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX-REPUTATION-SCORE` | 10,000 | Maximum achievable reputation |
| `BOOTSTRAP-REPUTATION` | 100 | Initial reputation for new users |
| `MIN-STAKE-AMOUNT` | 1,000,000 µSTX | Minimum stake (1 STX) |
| `DECAY-BLOCKS` | 144 | Blocks between decay cycles (~24 hours) |
| `MAX-DECAY-RATE` | 20% | Maximum reputation decay per cycle |

### Reputation Actions

The protocol supports various reputation-earning actions:

- **Governance Vote**: Base multiplier 10, max 3/day, verification required
- **Contract Fulfillment**: Base multiplier 25, max 5/day
- **Community Contribution**: Base multiplier 15, max 10/day
- **Peer Attestation**: Base multiplier 20, max 2/day, verification required
- **Dispute Resolution**: Base multiplier 30, max 1/day, verification required
- **Security Audit**: Base multiplier 50, max 1/day, verification required

## Security Features

### Input Validation

- **String Sanitization**: Prevents malicious input through `is-valid-string`
- **Type Validation**: Whitelisted attestation and proposal action types
- **Range Validation**: Numerical parameters within safe bounds

### Anti-Gaming Protections

- **Daily Activity Limits**: Prevents reputation farming
- **Verification Requirements**: Certain actions require verified status
- **Stake-Based Weighting**: Higher stakes provide reputation bonuses
- **Evidence Requirements**: Actions must include cryptographic evidence

### Access Control

- **Owner-Only Functions**: Critical admin functions restricted to contract owner
- **Governance Permissions**: Voting requires minimum reputation thresholds
- **Emergency Pause**: Protocol can be paused for security incidents

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `ERR-UNAUTHORIZED` | Insufficient permissions |
| u101 | `ERR-INVALID-PARAMETERS` | Invalid function parameters |
| u102 | `ERR-IDENTITY-EXISTS` | Identity already exists |
| u103 | `ERR-IDENTITY-NOT-FOUND` | Identity not found |
| u104 | `ERR-INSUFFICIENT-REPUTATION` | Minimum reputation not met |
| u106 | `ERR-INSUFFICIENT-STAKE` | Stake amount too low |
| u107 | `ERR-COOLDOWN-ACTIVE` | Daily limit reached |
| u110 | `ERR-PAUSED` | Protocol is paused |

## Testing

The protocol includes comprehensive tests using the Clarinet SDK and testing frameworks.

### Test Configuration

Tests are configured with:

- **Clarinet Environment**: Simulated Stacks blockchain
- **Pre-funded Accounts**: Multiple test wallets from `settings/Devnet.toml`
- **Coverage Reporting**: Code coverage and cost analysis

### Running Specific Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:report

# Watch mode
npm run test:watch
```

## Deployment

### Network Configuration

The protocol supports deployment to:

- **Devnet**: Local development (settings/Devnet.toml)
- **Testnet**: Public testing environment
- **Mainnet**: Production deployment

### Contract Deployment

1. **Configure Network**

   ```bash
   # Edit Clarinet.toml for target network
   clarinet settings set network <network-name>
   ```

2. **Deploy Contract**

   ```bash
   clarinet deploy --network <network-name>
   ```

## API Reference

### Public Functions

#### Identity Management

```clarity
(define-public (create-identity-with-stake (did (string-ascii 50)) (stake-amount uint)))
```

Creates a new identity with staking mechanism.

```clarity
(define-public (update-reputation-secure (action-type (string-ascii 50)) (evidence-hash (buff 32))))
```

Updates reputation score with anti-gaming protections.

#### Governance

```clarity
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (action-type (string-ascii 30)) (target-value uint)))
```

Creates a new governance proposal.

```clarity
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool)))
```

Votes on a governance proposal with reputation-weighted voting.

#### Attestations

```clarity
(define-public (create-attestation (target principal) (impact int) (attestation-type (string-ascii 30)) (duration-blocks uint)))
```

Creates peer attestations with impact validation.

### Read-Only Functions

```clarity
(define-read-only (get-reputation-profile (owner principal)))
```

Returns comprehensive reputation profile with decay calculations.

```clarity
(define-read-only (verify-advanced-reputation (owner principal) (min-base-reputation uint) (min-weighted-reputation uint) (min-verification-level uint)))
```

Verifies if user meets advanced reputation requirements.

```clarity
(define-read-only (get-protocol-stats))
```

Returns protocol-wide statistics and metrics.

## Roadmap

### Phase 1: Core Infrastructure ✅

- [x] Basic reputation system
- [x] Identity management
- [x] Staking mechanism
- [x] Security validations

### Phase 2: Governance & Attestations 🚧

- [x] Governance proposals and voting
- [x] Peer attestation system
- [ ] Advanced analytics dashboard
- [ ] Integration APIs

### Phase 3: Ecosystem Integration 📋

- [ ] Cross-application reputation portability
- [ ] Developer SDK and tools
- [ ] Mobile wallet integration
- [ ] DeFi protocol partnerships

### Phase 4: Advanced Features 📋

- [ ] AI-powered reputation analysis
- [ ] Cross-chain reputation bridges
- [ ] Enterprise reputation solutions
- [ ] Regulatory compliance tools

## Contributing

We welcome contributions to BitCred! Please see our contributing guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Run tests**: `npm test`
4. **Commit changes**: `git commit -m 'Add amazing feature'`
5. **Push to branch**: `git push origin feature/amazing-feature`
6. **Open a Pull Request**

### Development Guidelines

- Follow Clarity best practices
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure security validations for user inputs

## Use Cases

### DeFi Applications

- **Lending Protocols**: Use reputation scores for unsecured lending
- **DEX Trading**: Reputation-based trading limits and fee discounts
- **Yield Farming**: Enhanced rewards for high-reputation participants

### NFT & Gaming

- **Marketplace Trust**: Seller/buyer reputation for secure transactions
- **Gaming Guilds**: Merit-based leadership and resource allocation
- **Creator Verification**: Authenticated artist and creator profiles

### Enterprise Solutions

- **Supply Chain**: Vendor reputation and reliability tracking
- **Professional Services**: Freelancer and contractor credibility
- **B2B Transactions**: Business reputation for trade relationships

## License

This project is licensed under the ISC License.

## Contact & Support

- **Documentation**: This README and inline code comments
- **Issues**: GitHub Issues for bug reports and feature requests
- **Discussions**: GitHub Discussions for community questions

---

## Built with ❤️ on Bitcoin via Stacks

*BitCred is pioneering the future of decentralized reputation systems, making trust programmable and portable across the Bitcoin
