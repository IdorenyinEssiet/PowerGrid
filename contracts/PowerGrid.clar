;; PowerGrid: Energy Grid Management System
;; Version: 1.0.0

(define-data-var grid-coordinator principal tx-sender)
(define-data-var energy-reserves uint u0)
(define-data-var efficiency-rating uint u92) ;; efficiency points per assessment cycle
(define-data-var last-efficiency-check uint u0) ;; last block when efficiency was checked

(define-map producer-energy-output principal uint)

;; Helper function to ensure only the grid coordinator can perform certain actions
(define-private (is-grid-coordinator (caller principal))
  (begin
    (asserts! (is-eq caller (var-get grid-coordinator)) (err u400))
    (ok true)))

;; Initialize the energy grid platform
(define-public (establish-energy-grid (coordinator principal))
  (begin
    (asserts! (is-none (map-get? producer-energy-output coordinator)) (err u401))
    (var-set grid-coordinator coordinator)
    (ok "PowerGrid energy network established")))

;; Record energy production
(define-public (record-energy-production (kilowatts uint))
  (begin
    (asserts! (> kilowatts u0) (err u402))
    (let ((current-output (default-to u0 (map-get? producer-energy-output tx-sender))))
      (map-set producer-energy-output tx-sender (+ current-output kilowatts))
      (var-set energy-reserves (+ (var-get energy-reserves) kilowatts))
      (ok (+ current-output kilowatts)))))

;; Assess grid efficiency for all producers
(define-public (assess-grid-efficiency)
  (begin
    (try! (is-grid-coordinator tx-sender))
    (let ((current-block stacks-block-height)
          (previous-check (var-get last-efficiency-check)))
      (asserts! (> current-block previous-check) (err u403))
      ;; Calculate efficiency based on blocks elapsed
      (let ((elapsed (- current-block previous-check))
            (total-efficiency (* elapsed (var-get efficiency-rating))))
        (var-set last-efficiency-check current-block)
        (var-set energy-reserves (+ (var-get energy-reserves) total-efficiency))
        (ok total-efficiency)))))

;; Distribute energy and claim efficiency premiums
(define-public (distribute-efficiency-premium)
  (begin
    (let ((producer-output (default-to u0 (map-get? producer-energy-output tx-sender))))
      (asserts! (> producer-output u0) (err u404))
      (let ((total-reserves (var-get energy-reserves))
            (new-efficiency (* (var-get efficiency-rating) (- stacks-block-height (var-get last-efficiency-check))))
            (output-ratio (/ (* producer-output u100000) total-reserves)))
        ;; Calculate premium based on output ratio
        (let ((premium-amount (/ (* output-ratio new-efficiency) u100000)))
          (map-delete producer-energy-output tx-sender)
          (var-set energy-reserves (- (var-get energy-reserves) producer-output))
          (ok (+ producer-output premium-amount)))))))

;; Read-only functions
(define-read-only (get-producer-energy-output (producer principal))
  (default-to u0 (map-get? producer-energy-output producer)))

(define-read-only (get-grid-stats)
  {
    coordinator: (var-get grid-coordinator),
    total-reserves: (var-get energy-reserves),
    efficiency-rating: (var-get efficiency-rating),
    last-check: (var-get last-efficiency-check)
  })

(define-read-only (get-energy-reserves)
  (var-get energy-reserves))