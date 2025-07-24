;; EnergyChain: Decentralized Renewable Energy Trading Platform
;; Version: 1.0.0

(define-data-var grid-operator principal tx-sender)
(define-data-var energy-reserve uint u0)
(define-data-var carbon-credit-rate uint u120) ;; credits per megawatt hour
(define-data-var last-credit-calculation uint u0) ;; last block when credits were calculated

(define-map producer-installations principal uint)

;; Helper function to ensure only the grid operator can perform certain actions
(define-private (is-operator (caller principal))
  (begin
    (asserts! (is-eq caller (var-get grid-operator)) (err u300))
    (ok true)))

;; Initialize the energy trading platform
(define-public (activate-grid (operator principal))
  (begin
    (asserts! (is-none (map-get? producer-installations operator)) (err u301))
    (var-set grid-operator operator)
    (ok "EnergyChain grid activated")))

;; Register renewable energy production
(define-public (register-production (megawatts uint))
  (begin
    (asserts! (> megawatts u0) (err u302))
    (let ((current-capacity (default-to u0 (map-get? producer-installations tx-sender))))
      (map-set producer-installations tx-sender (+ current-capacity megawatts))
      (var-set energy-reserve (+ (var-get energy-reserve) megawatts))
      (ok (+ current-capacity megawatts)))))

;; Calculate carbon credits for all producers
(define-public (calculate-carbon-credits)
  (begin
    (try! (is-operator tx-sender))
    (let ((current-block stacks-block-height)
          (previous-calculation (var-get last-credit-calculation)))
      (asserts! (> current-block previous-calculation) (err u303))
      ;; Calculate credits based on blocks elapsed
      (let ((elapsed (- current-block previous-calculation))
            (total-credits (* elapsed (var-get carbon-credit-rate))))
        (var-set last-credit-calculation current-block)
        (var-set energy-reserve (+ (var-get energy-reserve) total-credits))
        (ok total-credits)))))

;; Sell energy and claim carbon credits
(define-public (trade-energy-credits)
  (begin
    (let ((producer-capacity (default-to u0 (map-get? producer-installations tx-sender))))
      (asserts! (> producer-capacity u0) (err u304))
      (let ((total-energy (var-get energy-reserve))
            (new-credits (* (var-get carbon-credit-rate) (- stacks-block-height (var-get last-credit-calculation))))
            (capacity-ratio (/ (* producer-capacity u100000) total-energy)))
        ;; Calculate credits based on capacity ratio
        (let ((credit-amount (/ (* capacity-ratio new-credits) u100000)))
          (map-delete producer-installations tx-sender)
          (var-set energy-reserve (- (var-get energy-reserve) producer-capacity))
          (ok (+ producer-capacity credit-amount)))))))

;; Read-only functions
(define-read-only (get-producer-capacity (producer principal))
  (default-to u0 (map-get? producer-installations producer)))

(define-read-only (get-grid-stats)
  {
    operator: (var-get grid-operator),
    total-reserve: (var-get energy-reserve),
    credit-rate: (var-get carbon-credit-rate),
    last-calculation: (var-get last-credit-calculation)
  })

(define-read-only (get-energy-reserve)
  (var-get energy-reserve))