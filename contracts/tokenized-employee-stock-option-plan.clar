;; SIP-010 Fungible Token Trait

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-RECIPIENT (err u104))
(define-constant ERR-EMPLOYEE-NOT-FOUND (err u105))
(define-constant ERR-INVALID-VESTING (err u106))
(define-constant ERR-NOT-VESTED (err u107))
(define-constant ERR-ALREADY-EXERCISED (err u108))
(define-constant ERR-MILESTONE-NOT-FOUND (err u109))
(define-constant ERR-MILESTONE-ALREADY-ACHIEVED (err u110))

(define-fungible-token esop-token)

(define-data-var token-name (string-ascii 32) "ESOP Token")
(define-data-var token-symbol (string-ascii 10) "ESOP")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var company-valuation uint u0)
(define-data-var total-shares uint u1000000)
(define-data-var exercise-price uint u10)

(define-map employee-options 
  principal 
  {
    total-options: uint,
    exercised-options: uint,
    grant-block: uint,
    cliff-blocks: uint,
    vesting-blocks: uint,
    active: bool,
    performance-bonus: uint
  }
)

(define-map performance-milestones
  uint
  {
    description: (string-ascii 100),
    target-metric: uint,
    bonus-percentage: uint,
    achieved: bool,
    achieved-block: uint
  }
)

(define-data-var milestone-counter uint u0)
(define-map authorized-issuers principal bool)

(define-public (get-name)
  (ok (var-get token-name))
)

(define-public (get-symbol)
  (ok (var-get token-symbol))
)

(define-public (get-decimals)
  (ok (var-get token-decimals))
)

(define-public (get-balance (user principal))
  (ok (ft-get-balance esop-token user))
)

(define-public (get-total-supply)
  (ok (ft-get-supply esop-token))
)

(define-public (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq from to)) ERR-INVALID-RECIPIENT)
    (ft-transfer? esop-token amount from to)
  )
)

(define-public (set-company-valuation (new-valuation uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set company-valuation new-valuation)
    (ok true)
  )
)

(define-public (set-exercise-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set exercise-price new-price)
    (ok true)
  )
)

(define-public (set-total-shares (new-total uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set total-shares new-total)
    (ok true)
  )
)

(define-public (grant-options (employee principal) (options uint) (cliff-blocks uint) (vesting-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> options u0) ERR-INVALID-AMOUNT)
    (asserts! (< cliff-blocks vesting-blocks) ERR-INVALID-VESTING)
    
    (map-set employee-options employee {
      total-options: options,
      exercised-options: u0,
      grant-block: burn-block-height,
      cliff-blocks: cliff-blocks,
      vesting-blocks: vesting-blocks,
      active: true,
      performance-bonus: u0
    })
    (ok true)
  )
)

(define-read-only (calculate-vested-options (employee principal))
  (match (map-get? employee-options employee)
    option-data
      (let
        (
          (current-block burn-block-height)
          (grant-block (get grant-block option-data))
          (cliff-blocks (get cliff-blocks option-data))
          (vesting-blocks (get vesting-blocks option-data))
          (total-options (get total-options option-data))
          (performance-bonus (get performance-bonus option-data))
          (blocks-elapsed (- current-block grant-block))
          (base-vested (if (< blocks-elapsed cliff-blocks)
                         u0
                         (if (>= blocks-elapsed vesting-blocks)
                           total-options
                           (/ (* total-options blocks-elapsed) vesting-blocks))))
        )
        (if (get active option-data)
          (+ base-vested performance-bonus)
          u0
        )
      )
    u0
  )
)

(define-read-only (get-exercisable-options (employee principal))
  (match (map-get? employee-options employee)
    option-data
      (let
        (
          (vested-options (calculate-vested-options employee))
          (exercised-options (get exercised-options option-data))
        )
        (if (>= vested-options exercised-options)
          (- vested-options exercised-options)
          u0
        )
      )
    u0
  )
)

(define-public (exercise-options (amount uint))
  (let
    (
      (employee tx-sender)
      (option-data (unwrap! (map-get? employee-options employee) ERR-EMPLOYEE-NOT-FOUND))
      (exercisable (get-exercisable-options employee))
    )
    (asserts! (get active option-data) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount exercisable) ERR-NOT-VESTED)
    
    (map-set employee-options employee 
      (merge option-data {exercised-options: (+ (get exercised-options option-data) amount)})
    )
    
    (ft-mint? esop-token amount employee)
  )
)

(define-read-only (get-option-value (employee principal))
  (let
    (
      (vested-options (calculate-vested-options employee))
      (company-val (var-get company-valuation))
      (total-shares-val (var-get total-shares))
      (exercise-price-val (var-get exercise-price))
    )
    (if (and (> company-val u0) (> total-shares-val u0))
      (let
        (
          (share-price (/ company-val total-shares-val))
          (intrinsic-value (if (> share-price exercise-price-val)
                             (- share-price exercise-price-val)
                             u0))
        )
        (* vested-options intrinsic-value)
      )
      u0
    )
  )
)

(define-read-only (get-employee-options (employee principal))
  (map-get? employee-options employee)
)

(define-read-only (get-company-metrics)
  {
    valuation: (var-get company-valuation),
    total-shares: (var-get total-shares),
    exercise-price: (var-get exercise-price),
    share-price: (if (> (var-get total-shares) u0)
                   (/ (var-get company-valuation) (var-get total-shares))
                   u0)
  }
)

(define-public (revoke-options (employee principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (match (map-get? employee-options employee)
      option-data
        (begin
          (map-set employee-options employee (merge option-data {active: false}))
          (ok true)
        )
      ERR-EMPLOYEE-NOT-FOUND
    )
  )
)

(define-public (batch-grant-options (employees (list 20 {employee: principal, options: uint, cliff: uint, vesting: uint})))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (fold grant-single-option employees (ok true))
  )
)

(define-private (grant-single-option (employee-data {employee: principal, options: uint, cliff: uint, vesting: uint}) (prev-result (response bool uint)))
  (match prev-result
    success
      (grant-options 
        (get employee employee-data) 
        (get options employee-data) 
        (get cliff employee-data) 
        (get vesting employee-data)
      )
    error
      prev-result
  )
)

(define-read-only (get-portfolio-value (employee principal))
  (let
    (
      (token-balance (ft-get-balance esop-token employee))
      (option-value (get-option-value employee))
      (company-val (var-get company-valuation))
      (total-shares-val (var-get total-shares))
    )
    (if (and (> company-val u0) (> total-shares-val u0))
      (let
        (
          (share-price (/ company-val total-shares-val))
          (token-value (* token-balance share-price))
        )
        (+ token-value option-value)
      )
      u0
    )
  )
)

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (ok true)
  )
)

(define-read-only (calculate-dilution (new-options uint))
  (let
    (
      (current-supply (ft-get-supply esop-token))
      (total-outstanding (+ current-supply new-options))
    )
    (if (> total-outstanding u0)
      (/ (* new-options u10000) total-outstanding)
      u0
    )
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set token-uri new-uri)
    (ok true)
  )
)

(define-public (create-performance-milestone (description (string-ascii 100)) (target-metric uint) (bonus-percentage uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> bonus-percentage u0) ERR-INVALID-AMOUNT)
    (asserts! (<= bonus-percentage u100) ERR-INVALID-AMOUNT)
    
    (let
      (
        (milestone-id (var-get milestone-counter))
      )
      (map-set performance-milestones milestone-id {
        description: description,
        target-metric: target-metric,
        bonus-percentage: bonus-percentage,
        achieved: false,
        achieved-block: u0
      })
      (var-set milestone-counter (+ milestone-id u1))
      (ok milestone-id)
    )
  )
)

(define-public (achieve-milestone (milestone-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (match (map-get? performance-milestones milestone-id)
      milestone-data
        (begin
          (asserts! (not (get achieved milestone-data)) ERR-MILESTONE-ALREADY-ACHIEVED)
          (map-set performance-milestones milestone-id 
            (merge milestone-data {achieved: true, achieved-block: burn-block-height})
          )
          (ok true)
        )
      ERR-MILESTONE-NOT-FOUND
    )
  )
)

(define-public (apply-performance-bonus (employee principal) (milestone-id uint))
  (let
    (
      (milestone-data (unwrap! (map-get? performance-milestones milestone-id) ERR-MILESTONE-NOT-FOUND))
      (employee-data (unwrap! (map-get? employee-options employee) ERR-EMPLOYEE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (get achieved milestone-data) ERR-MILESTONE-NOT-FOUND)
    (asserts! (get active employee-data) ERR-NOT-AUTHORIZED)
    
    (let
      (
        (total-options (get total-options employee-data))
        (bonus-percentage (get bonus-percentage milestone-data))
        (bonus-options (/ (* total-options bonus-percentage) u100))
        (current-bonus (get performance-bonus employee-data))
        (new-bonus (+ current-bonus bonus-options))
      )
      (map-set employee-options employee 
        (merge employee-data {performance-bonus: new-bonus})
      )
      (ok bonus-options)
    )
  )
)

(define-read-only (get-performance-milestone (milestone-id uint))
  (map-get? performance-milestones milestone-id)
)

(define-read-only (get-total-performance-bonuses (employee principal))
  (match (map-get? employee-options employee)
    option-data
      (get performance-bonus option-data)
    u0
  )
)

(define-read-only (calculate-potential-bonus (employee principal) (milestone-id uint))
  (match (map-get? performance-milestones milestone-id)
    milestone-data
      (match (map-get? employee-options employee)
        employee-data
          (let
            (
              (total-options (get total-options employee-data))
              (bonus-percentage (get bonus-percentage milestone-data))
            )
            (/ (* total-options bonus-percentage) u100)
          )
        u0
      )
    u0
  )
)

(map-set authorized-issuers CONTRACT-OWNER true)
