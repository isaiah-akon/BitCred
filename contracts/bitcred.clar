;; Title: BitCred - Bitcoin-Native Reputation Protocol
;;
;; Summary: 
;; A revolutionary Bitcoin Layer-2 protocol that transforms digital 
;; interactions through verifiable reputation mechanics built on 
;; Stacks blockchain infrastructure.
;;
;; Description:
;; BitCred establishes the first comprehensive reputation economy 
;; native to Bitcoin's ecosystem. By leveraging Stacks' smart contract 
;; capabilities, this protocol creates immutable credential systems 
;; where reputation becomes programmable money. Users earn credibility 
;; through verified actions, building portable trust scores that unlock 
;; economic opportunities across Bitcoin-powered applications.

;; PROTOCOL CONSTANTS & CONFIGURATION

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMETERS (err u101))
(define-constant ERR-IDENTITY-EXISTS (err u102))
(define-constant ERR-IDENTITY-NOT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u104))
(define-constant ERR-MAX-REPUTATION-REACHED (err u105))
(define-constant ERR-INSUFFICIENT-STAKE (err u106))
(define-constant ERR-COOLDOWN-ACTIVE (err u107))
(define-constant ERR-INVALID-ATTESTATION (err u108))
(define-constant ERR-GOVERNANCE-ONLY (err u109))
(define-constant ERR-PAUSED (err u110))
(define-constant ERR-INVALID-STRING (err u111))
(define-constant ERR-INVALID-DURATION (err u112))

;; Protocol Configuration
(define-constant MAX-REPUTATION-SCORE u10000)
(define-constant MIN-REPUTATION-SCORE u0)
(define-constant BOOTSTRAP-REPUTATION u100)
(define-constant DECAY-BLOCKS u144) ;; ~24 hours in blocks
(define-constant MAX-DECAY-RATE u20) ;; Maximum 20% decay
(define-constant MIN-STAKE-AMOUNT u1000000) ;; 1 STX in microSTX
(define-constant COOLDOWN-BLOCKS u6) ;; ~1 hour cooldown
(define-constant MAX-PROPOSAL-DURATION u2016) ;; ~2 weeks max
(define-constant MIN-PROPOSAL-DURATION u144) ;; ~1 day min
(define-constant MAX-ATTESTATION-DURATION u14400) ;; ~100 days max

;; Contract owner for governance
(define-constant CONTRACT-OWNER tx-sender)

;; Allowed attestation types (whitelist approach) - matching (string-ascii 30)
(define-constant VALID-ATTESTATION-TYPES (list 
  "peer-review" "code-audit" "transaction-verify" "dispute-resolve" 
  "community-help" "security-report" "bug-report" "improvement"
))

;; Allowed action types for proposals - matching (string-ascii 30)
(define-constant VALID-PROPOSAL-ACTIONS (list
  "update-multiplier" "add-action-type" "change-governance" 
  "emergency-pause" "protocol-upgrade" "fee-adjustment"
))

;; DATA STRUCTURES

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
    verification-level: uint, ;; 0=basic, 1=verified, 2=premium
  }
)

;; Reputation Actions with Metadata
(define-map reputation-actions
  { action-type: (string-ascii 50) }
  { 
    base-multiplier: uint,
    max-daily-applications: uint,
    verification-required: bool,
    enabled: bool
  }
)

;; Daily Activity Tracking (Sybil Resistance)
(define-map daily-activities
  { owner: principal, day: uint, action-type: (string-ascii 50) }
  { count: uint }
)

;; Cross-Application Attestations
(define-map attestations
  { attester: principal, target: principal }
  {
    reputation-impact: int, ;; Can be negative
    attestation-type: (string-ascii 30),
    created-at: uint,
    expires-at: uint,
  }
)

;; Governance Proposals
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    action-type: (string-ascii 30),
    target-value: uint,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    expires-at: uint,
    executed: bool,
  }
)

;; Governance Votes
(define-map votes
  { proposal-id: uint, voter: principal }
  { 
    vote: bool, ;; true=for, false=against
    weight: uint,
    cast-at: uint
  }
)

;; Protocol State
(define-data-var protocol-paused bool false)
(define-data-var proposal-counter uint u0)
(define-data-var total-staked uint u0)

;; SECURITY VALIDATION FUNCTIONS

;; Validate string input for malicious content
(define-private (is-valid-string (input (string-ascii 500)))
  (and
    (> (len input) u0)
    (<= (len input) u500)
    ;; Check for basic ASCII printable characters (32-126)
    ;; This is a simplified check - in production, you'd want more robust validation
    (not (is-eq (element-at input u0) (some " "))) ;; No leading spaces
  )
)

;; Validate attestation type against known patterns
(define-private (is-valid-attestation-type (att-type (string-ascii 30)))
  (or
    (is-eq att-type "peer-review")
    (is-eq att-type "code-audit")
    (is-eq att-type "transaction-verify")
    (is-eq att-type "dispute-resolve")
    (is-eq att-type "community-help")
    (is-eq att-type "security-report")
    (is-eq att-type "bug-report")
    (is-eq att-type "improvement")
  )
)

;; Validate proposal action type
(define-private (is-valid-proposal-action (action (string-ascii 30)))
  (or
    (is-eq action "update-multiplier")
    (is-eq action "add-action-type")
    (is-eq action "change-governance")
    (is-eq action "emergency-pause")
    (is-eq action "protocol-upgrade")
    (is-eq action "fee-adjustment")
  )
)

;; Validate duration parameters
(define-private (is-valid-duration (duration uint) (max-duration uint))
  (and
    (> duration u0)
    (<= duration max-duration)
  )
)

;; Validate numerical ranges
(define-private (is-valid-range (value uint) (min-val uint) (max-val uint))
  (and
    (>= value min-val)
    (<= value max-val)
  )
)

;; PRIVATE UTILITY FUNCTIONS

;; Mathematical utility functions
(define-private (min (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (>= a b) a b)
)

(define-private (abs (n int))
  (if (>= n 0) (to-uint n) (to-uint (- 0 n)))
)

;; Authorization Check
(define-private (is-authorized-user (owner principal))
  (and
    (is-some (map-get? identities { owner: owner }))
    (is-eq owner tx-sender)
    (not (var-get protocol-paused))
  )
)

;; Governance Authorization
(define-private (is-governance-member (caller principal))
  (let ((identity (map-get? identities { owner: caller })))
    (match identity
      id (>= (get verification-level id) u1)
      false
    )
  )
)

;; Calculate Current Day (for daily limits)
(define-private (get-current-day)
  (/ stacks-block-height u144) ;; Assuming ~10min blocks
)

;; Calculate Weighted Reputation Score
(define-private (calculate-weighted-score 
    (base-score uint) 
    (stake uint) 
    (activity uint)
    (verification uint))
  (let (
    (stake-bonus (/ (* stake u10) MIN-STAKE-AMOUNT))
    (activity-bonus (min u500 (* activity u5)))
    (verification-bonus (* verification u100))
  )
    (min MAX-REPUTATION-SCORE
      (+ base-score stake-bonus activity-bonus verification-bonus)
    )
  )
)

;; Apply Time-Based Decay
(define-private (apply-reputation-decay (identity-data (tuple 
    (did (string-ascii 50))
    (reputation-score uint)
    (weighted-score uint)
    (stake-amount uint)
    (created-at uint)
    (last-updated uint)
    (last-decay uint)
    (activity-count uint)
    (verification-level uint))))
  (let (
    (blocks-since-decay (- stacks-block-height (get last-decay identity-data)))
    (decay-periods (/ blocks-since-decay DECAY-BLOCKS))
    (current-score (get reputation-score identity-data))
  )
    (if (> decay-periods u0)
      (let (
        (decay-rate (min MAX-DECAY-RATE (+ u5 (/ decay-periods u10))))
        (decay-amount (/ (* current-score decay-rate) u100))
        (new-score (if (> current-score decay-amount)
          (- current-score decay-amount)
          MIN-REPUTATION-SCORE))
      )
        (merge identity-data {
          reputation-score: new-score,
          last-decay: stacks-block-height
        })
      )
      identity-data
    )
  )
)

;; INITIALIZATION FUNCTIONS

;; Initialize Reputation Actions
(define-public (initialize-enhanced-actions)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    ;; Core Actions
    (map-set reputation-actions { action-type: "governance-vote" } 
      { base-multiplier: u10, max-daily-applications: u3, verification-required: true, enabled: true })
    
    (map-set reputation-actions { action-type: "contract-fulfillment" } 
      { base-multiplier: u25, max-daily-applications: u5, verification-required: false, enabled: true })
    
    (map-set reputation-actions { action-type: "community-contribution" } 
      { base-multiplier: u15, max-daily-applications: u10, verification-required: false, enabled: true })
    
    (map-set reputation-actions { action-type: "peer-attestation" } 
      { base-multiplier: u20, max-daily-applications: u2, verification-required: true, enabled: true })
    
    (map-set reputation-actions { action-type: "dispute-resolution" } 
      { base-multiplier: u30, max-daily-applications: u1, verification-required: true, enabled: true })
    
    (map-set reputation-actions { action-type: "security-audit" } 
      { base-multiplier: u50, max-daily-applications: u1, verification-required: true, enabled: true })
    
    (ok true)
  )
)

;; CORE IDENTITY FUNCTIONS

;; Create Identity with Staking
(define-public (create-identity-with-stake (did (string-ascii 50)) (stake-amount uint))
  (let (
    (sender tx-sender)
    (current-block stacks-block-height)
  )
    (begin
      (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
      (asserts! (is-none (map-get? identities { owner: sender })) ERR-IDENTITY-EXISTS)
      (asserts! (is-valid-string did) ERR-INVALID-STRING)
      (asserts! (> (len did) u5) ERR-INVALID-PARAMETERS)
      (asserts! (>= stake-amount MIN-STAKE-AMOUNT) ERR-INSUFFICIENT-STAKE)
      (asserts! (is-valid-range stake-amount MIN-STAKE-AMOUNT (* MIN-STAKE-AMOUNT u1000)) ERR-INVALID-PARAMETERS)
      
      ;; Transfer stake to contract (in a real implementation, this would use STX transfer)
      ;; For now, we'll track the commitment
      
      (map-set identities { owner: sender } {
        did: did,
        reputation-score: BOOTSTRAP-REPUTATION,
        weighted-score: (calculate-weighted-score BOOTSTRAP-REPUTATION stake-amount u0 u0),
        stake-amount: stake-amount,
        created-at: current-block,
        last-updated: current-block,
        last-decay: current-block,
        activity-count: u0,
        verification-level: u0,
      })
      
      (var-set total-staked (+ (var-get total-staked) stake-amount))
      (ok did)
    )
  )
)

;; Reputation Update with Anti-Gaming
(define-public (update-reputation-secure (action-type (string-ascii 50)) (evidence-hash (buff 32)))
  (let (
    (owner tx-sender)
    (current-day (get-current-day))
    (current-identity (unwrap! (map-get? identities { owner: owner }) ERR-IDENTITY-NOT-FOUND))
    (action-config (unwrap! (map-get? reputation-actions { action-type: action-type }) ERR-INVALID-PARAMETERS))
    (daily-activity-key { owner: owner, day: current-day, action-type: action-type })
    (current-daily-count (default-to u0 (get count (map-get? daily-activities daily-activity-key))))
  )
    (begin
      (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
      (asserts! (is-valid-string action-type) ERR-INVALID-STRING)
      (asserts! (get enabled action-config) ERR-INVALID-PARAMETERS)
      (asserts! (< current-daily-count (get max-daily-applications action-config)) ERR-COOLDOWN-ACTIVE)
      
      ;; Evidence hash validation (must be non-zero)
      (asserts! (not (is-eq evidence-hash 0x0000000000000000000000000000000000000000000000000000000000000000)) ERR-INVALID-PARAMETERS)
      
      ;; Verification check if required
      (asserts! 
        (or 
          (not (get verification-required action-config))
          (>= (get verification-level current-identity) u1)
        )
        ERR-UNAUTHORIZED
      )
      
      ;; Apply decay before update
      (let (
        (decayed-identity (apply-reputation-decay current-identity))
        (current-score (get reputation-score decayed-identity))
        (base-multiplier (get base-multiplier action-config))
        (activity-count (+ (get activity-count decayed-identity) u1))
        
        ;; Dynamic multiplier based on verification level and stake
        (verification-bonus (+ u100 (* (get verification-level current-identity) u20)))
        (stake-bonus (+ u100 (min u50 (/ (get stake-amount current-identity) MIN-STAKE-AMOUNT))))
        (total-multiplier (/ (* base-multiplier verification-bonus stake-bonus) u10000))
        
        (reputation-gain (min u100 total-multiplier)) ;; Cap individual gains
        (updated-score (min MAX-REPUTATION-SCORE (+ current-score reputation-gain)))
        (updated-weighted-score (calculate-weighted-score 
          updated-score 
          (get stake-amount decayed-identity)
          activity-count
          (get verification-level decayed-identity)))
      )
        
        ;; Update daily activity counter
        (map-set daily-activities daily-activity-key { count: (+ current-daily-count u1) })
        
        ;; Update identity
        (map-set identities { owner: owner }
          (merge decayed-identity {
            reputation-score: updated-score,
            weighted-score: updated-weighted-score,
            last-updated: stacks-block-height,
            activity-count: activity-count,
          })
        )
        
        (ok updated-score)
      )
    )
  )
)

;; ATTESTATION SYSTEM

;; Create Peer Attestation with Security
(define-public (create-attestation 
    (target principal) 
    (impact int) 
    (attestation-type (string-ascii 30))
    (duration-blocks uint))
  (let (
    (attester tx-sender)
    (attester-identity (unwrap! (map-get? identities { owner: attester }) ERR-IDENTITY-NOT-FOUND))
    (target-identity (unwrap! (map-get? identities { owner: target }) ERR-IDENTITY-NOT-FOUND))
  )
    (begin
      (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
      (asserts! (not (is-eq attester target)) ERR-INVALID-PARAMETERS)
      (asserts! (>= (get verification-level attester-identity) u1) ERR-UNAUTHORIZED)
      (asserts! (<= (abs impact) u50) ERR-INVALID-PARAMETERS) ;; Limit impact
      (asserts! (is-valid-attestation-type attestation-type) ERR-INVALID-STRING)
      (asserts! (is-valid-duration duration-blocks MAX-ATTESTATION-DURATION) ERR-INVALID-DURATION)
      
      ;; Validate impact is reasonable based on attester's reputation
      (asserts! (<= (abs impact) (/ (get weighted-score attester-identity) u20)) ERR-INVALID-ATTESTATION)
      
      (map-set attestations { attester: attester, target: target } {
        reputation-impact: impact,
        attestation-type: attestation-type,
        created-at: stacks-block-height,
        expires-at: (+ stacks-block-height duration-blocks),
      })
      
      (ok true)
    )
  )
)

;; GOVERNANCE SYSTEM

;; Create Governance Proposal with Validation
(define-public (create-proposal 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (action-type (string-ascii 30))
    (target-value uint))
  (let (
    (proposer tx-sender)
    (proposer-identity (unwrap! (map-get? identities { owner: proposer }) ERR-IDENTITY-NOT-FOUND))
    (proposal-id (+ (var-get proposal-counter) u1))
  )
    (begin
      (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
      (asserts! (>= (get weighted-score proposer-identity) u500) ERR-INSUFFICIENT-REPUTATION)
      
      ;; input validation
      (asserts! (is-valid-string title) ERR-INVALID-STRING)
      (asserts! (is-valid-string description) ERR-INVALID-STRING)
      (asserts! (is-valid-proposal-action action-type) ERR-INVALID-STRING)
      (asserts! (> (len title) u10) ERR-INVALID-PARAMETERS) ;; Minimum title length
      (asserts! (> (len description) u20) ERR-INVALID-PARAMETERS) ;; Minimum description length
      
      ;; Validate target value based on action type
      (asserts! (or
        (and (is-eq action-type "update-multiplier") (<= target-value u200)) ;; Max 200% multiplier
        (and (is-eq action-type "fee-adjustment") (<= target-value u1000000)) ;; Max 1 STX fee
        (<= target-value u10000) ;; General max value
      ) ERR-INVALID-PARAMETERS)
      
      (map-set proposals { proposal-id: proposal-id } {
        proposer: proposer,
        title: title,
        description: description,
        action-type: action-type,
        target-value: target-value,
        votes-for: u0,
        votes-against: u0,
        created-at: stacks-block-height,
        expires-at: (+ stacks-block-height u1008), ;; ~1 week
        executed: false,
      })
      
      (var-set proposal-counter proposal-id)
      (ok proposal-id)
    )
  )
)

;; Vote on Governance Proposal with Security
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (voter tx-sender)
    (voter-identity (unwrap! (map-get? identities { owner: voter }) ERR-IDENTITY-NOT-FOUND))
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-INVALID-PARAMETERS))
    (vote-weight (get weighted-score voter-identity))
  )
    (begin
      (asserts! (not (var-get protocol-paused)) ERR-PAUSED)
      (asserts! (is-governance-member voter) ERR-UNAUTHORIZED)
      (asserts! (< stacks-block-height (get expires-at proposal)) ERR-INVALID-PARAMETERS)
      (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: voter })) ERR-INVALID-PARAMETERS)
      
      ;; Validate proposal ID is reasonable
      (asserts! (and (> proposal-id u0) (<= proposal-id (var-get proposal-counter))) ERR-INVALID-PARAMETERS)
      
      ;; Minimum reputation requirement for voting
      (asserts! (>= vote-weight u200) ERR-INSUFFICIENT-REPUTATION)
      
      ;; Record vote
      (map-set votes { proposal-id: proposal-id, voter: voter } {
        vote: vote-for,
        weight: vote-weight,
        cast-at: stacks-block-height,
      })
      
      ;; Update proposal vote counts
      (map-set proposals { proposal-id: proposal-id }
        (if vote-for
          (merge proposal { votes-for: (+ (get votes-for proposal) vote-weight) })
          (merge proposal { votes-against: (+ (get votes-against proposal) vote-weight) })
        )
      )
      
      (ok true)
    )
  )
)

;; READ-ONLY QUERY FUNCTIONS

;; Get Reputation Profile
(define-read-only (get-reputation-profile (owner principal))
  (match (map-get? identities { owner: owner })
    identity-data (let (
      (current-identity (apply-reputation-decay identity-data))
      ;; Simplified attestation impact - in practice would query attestation map
      (attestation-impact u0)
    )
      (some {
        basic-info: current-identity,
        attestation-bonus: attestation-impact,
        total-effective-score: (+ (get weighted-score current-identity) attestation-impact),
      })
    )
    none
  )
)

;; Helper function for attestation impact calculation
(define-private (get-attestation-impact (attestation-data (tuple 
    (reputation-impact int)
    (attestation-type (string-ascii 30))
    (created-at uint)
    (expires-at uint))))
  (if (> (get expires-at attestation-data) stacks-block-height)
    (abs (get reputation-impact attestation-data))
    u0
  )
)

;; Verify Advanced Reputation Requirements
(define-read-only (verify-advanced-reputation
    (owner principal)
    (min-base-reputation uint)
    (min-weighted-reputation uint)
    (min-verification-level uint))
  (match (map-get? identities { owner: owner })
    identity (and
      (>= (get reputation-score identity) min-base-reputation)
      (>= (get weighted-score identity) min-weighted-reputation)
      (>= (get verification-level identity) min-verification-level)
    )
    false
  )
)

;; Get Protocol Statistics
(define-read-only (get-protocol-stats)
  {
    total-identities: u0, ;; Would need to be tracked separately
    total-staked: (var-get total-staked),
    protocol-paused: (var-get protocol-paused),
    active-proposals: u0, ;; Would need to be calculated
  }
)

;; Get Proposal Details (secure)
(define-read-only (get-proposal-details (proposal-id uint))
  (if (and (> proposal-id u0) (<= proposal-id (var-get proposal-counter)))
    (map-get? proposals { proposal-id: proposal-id })
    none
  )
)

;; ADMIN FUNCTIONS

;; Emergency Pause Protocol
(define-public (pause-protocol)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set protocol-paused true)
    (ok true)
  )
)

;; Resume Protocol
(define-public (resume-protocol)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set protocol-paused false)
    (ok true)
  )
)

;; Update Action Configuration (Admin Only)
(define-public (update-action-config 
    (action-type (string-ascii 50))
    (base-multiplier uint)
    (max-daily-applications uint)
    (verification-required bool)
    (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-valid-string action-type) ERR-INVALID-STRING)
    (asserts! (is-valid-range base-multiplier u1 u100) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-range max-daily-applications u1 u50) ERR-INVALID-PARAMETERS)
    
    (map-set reputation-actions { action-type: action-type } {
      base-multiplier: base-multiplier,
      max-daily-applications: max-daily-applications,
      verification-required: verification-required,
      enabled: enabled
    })
    
    (ok true)
  )
)

;; CONTRACT INITIALIZATION

;; Initialize the protocol
(initialize-enhanced-actions)