# 🚀 Tokenized Employee Stock Option Plan (ESOP)

💼 A smart contract system for managing employee stock options with time-based vesting and corporate tokenomics on Stacks blockchain

## ✨ Features

### 🎯 Core Functionality
- **📝 Option Granting**: Issue stock options to employees with customizable terms
- **⏰ Time-Based Vesting**: Linear vesting with cliff periods using block height
- **💰 Option Exercise**: Convert vested options into tradeable tokens
- **📊 Real-time Valuation**: Dynamic option value calculation based on company metrics

### 🏢 Corporate Tokenomics
- **💎 Company Valuation**: Track and update company valuation
- **📈 Share Price Calculation**: Automatic per-share price based on valuation/shares
- **💲 Exercise Price**: Configurable strike price for option exercise
- **📉 Dilution Analysis**: Calculate dilution impact of new option grants

### 🔐 Governance & Security
- **👑 Owner Controls**: Admin functions for company management
- **🚫 Revocation**: Ability to revoke employee options
- **📦 Batch Operations**: Grant options to multiple employees at once
- **🔒 SIP-010 Compliance**: Full fungible token standard implementation

## 🛠️ Usage

### Deploy Contract
```bash
clarinet deployments generate --devnet
clarinet deployments apply -p deployments/default.devnet-plan.yaml
```

### 📋 Admin Functions

#### Set Company Metrics
```clarity
;; Set company valuation to $10M
(contract-call? .tokenized-employee-stock-option-plan set-company-valuation u10000000)

;; Set total shares to 1M
(contract-call? .tokenized-employee-stock-option-plan set-total-shares u1000000)

;; Set exercise price to $5
(contract-call? .tokenized-employee-stock-option-plan set-exercise-price u5)
```

#### Grant Stock Options
```clarity
;; Grant 1,000 options with 1-year cliff and 4-year vesting
(contract-call? .tokenized-employee-stock-option-plan grant-options 
  'SP1EMPLOYEE123
  u1000      ;; 1,000 options
  u52560     ;; ~1 year cliff (blocks)
  u210240    ;; ~4 years vesting (blocks)
)
```

#### Batch Grant Options
```clarity
(contract-call? .tokenized-employee-stock-option-plan batch-grant-options 
  (list 
    {employee: 'SP1EMP1, options: u1000, cliff: u52560, vesting: u210240}
    {employee: 'SP2EMP2, options: u500, cliff: u26280, vesting: u105120}
  )
)
```

### 👨‍💼 Employee Functions

#### Check Vested Options
```clarity
;; See how many options have vested
(contract-call? .tokenized-employee-stock-option-plan calculate-vested-options 'SP1EMPLOYEE123)

;; Check exercisable options (vested - already exercised)
(contract-call? .tokenized-employee-stock-option-plan get-exercisable-options 'SP1EMPLOYEE123)
```

#### Exercise Options
```clarity
;; Exercise 100 vested options
(contract-call? .tokenized-employee-stock-option-plan exercise-options u100)
```

#### Portfolio Tracking
```clarity
;; Get total portfolio value (tokens + unvested options)
(contract-call? .tokenized-employee-stock-option-plan get-portfolio-value 'SP1EMPLOYEE123)

;; Get current option value
(contract-call? .tokenized-employee-stock-option-plan get-option-value 'SP1EMPLOYEE123)
```

### 📊 Query Functions

#### Company Metrics
```clarity
;; Get all company metrics
(contract-call? .tokenized-employee-stock-option-plan get-company-metrics)
;; Returns: {valuation: u10000000, total-shares: u1000000, exercise-price: u5, share-price: u10}
```

#### Employee Data
```clarity
;; Get employee option details
(contract-call? .tokenized-employee-stock-option-plan get-employee-options 'SP1EMPLOYEE123)
```

#### Token Functions
```clarity
;; Standard SIP-010 functions
(contract-call? .tokenized-employee-stock-option-plan get-balance 'SP1EMPLOYEE123)
(contract-call? .tokenized-employee-stock-option-plan get-total-supply)
(contract-call? .tokenized-employee-stock-option-plan transfer u100 tx-sender 'SP2RECIPIENT memo)
```

## 🧮 Vesting Calculation

The contract uses **linear vesting** with the following logic:

- **Before Cliff**: 0% vested
- **After Cliff**: `(blocks_elapsed / total_vesting_blocks) * total_options`
- **Fully Vested**: After vesting period completes

Example with 1,000 options, 1-year cliff, 4-year vesting:
- Year 0-1: 0 options vested
- Year 2: 250 options vested (25%)
- Year 3: 500 options vested (50%)
- Year 4: 750 options vested (75%)
- Year 4+: 1,000 options vested (100%)

## 💡 Value Calculation

**Option Value** = `vested_options × (share_price - exercise_price)`

Where:
- `share_price = company_valuation ÷ total_shares`
- Negative intrinsic value = 0 (options underwater)

## 🧪 Testing

```bash
# Run all tests
clarinet test

# Check syntax
clarinet check

# Console testing
clarinet console
```

## 📁 Project Structure

```
├── contracts/
│   └── tokenized-employee-stock-option-plan.clar
├── tests/
│   └── tokenized-employee-stock-option-plan_test.ts
├── settings/
├── Clarinet.toml
└── README.md
```

## 🔒 Security Features

- ✅ Owner-only administrative functions
- ✅ Input validation and bounds checking  
- ✅ Safe arithmetic operations
- ✅ Protection against unauthorized transfers
- ✅ Option revocation capabilities
- ✅ SIP-010 standard compliance

## 🎯 Key Benefits

- **🌐 Blockchain Native**: Transparent and immutable option grants
- **⚡ Real-time**: Instant vesting calculations and value updates
- **🔄 Liquid**: Exercised options become tradeable tokens
- **📊 Transparent**: All metrics and grants are publicly verifiable
- **🔧 Flexible**: Customizable vesting schedules per employee
- **💼 Professional**: Enterprise-ready with governance features

## 🚨 Important Notes

- Block height is used for time calculations (~10 minutes per block on Stacks)
- Only contract owner can grant/revoke options and update company metrics
- Employees must have vested options before exercising
- All monetary values should use appropriate decimals (default: 6)
- Options become worthless if share price ≤ exercise price

---

**Built with ❤️ on Stacks blockchain using Clarity smart contracts**
