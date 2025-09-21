
;; title: EscrowAgent
;; version: 1.0.0
;; summary: Address reputation system for escrow service provider trustworthiness scoring
;; description: A smart contract that tracks and manages reputation scores for escrow agents
;;              based on transaction history, dispute resolution, and community feedback.

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-AGENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-SCORE (err u102))
(define-constant ERR-TRANSACTION-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-RATED (err u104))
(define-constant ERR-INVALID-RATING (err u105))
(define-constant ERR-AGENT-ALREADY-EXISTS (err u106))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-REPUTATION-SCORE u0)
(define-constant MAX-REPUTATION-SCORE u1000)
(define-constant INITIAL-REPUTATION-SCORE u500)

;; Data variables
(define-data-var next-transaction-id uint u1)

;; Data maps

;; Agent reputation data
(define-map agent-reputation
    { agent: principal }
    {
        score: uint,
        total-transactions: uint,
        successful-transactions: uint,
        disputed-transactions: uint,
        total-volume: uint,
        registration-block: uint,
        is-active: bool
    }
)

;; Transaction records
(define-map escrow-transactions
    { transaction-id: uint }
    {
        agent: principal,
        client: principal,
        amount: uint,
        status: (string-ascii 20),
        created-block: uint,
        completed-block: (optional uint)
    }
)

;; Client ratings for agents
(define-map client-ratings
    { client: principal, agent: principal, transaction-id: uint }
    {
        rating: uint,
        comment: (string-utf8 256),
        block-height: uint
    }
)

;; Agent verification status
(define-map agent-verification
    { agent: principal }
    {
        is-verified: bool,
        verifier: principal,
        verification-block: uint
    }
)

;; Public functions

;; Register a new escrow agent
(define-public (register-agent)
    (let ((agent tx-sender))
        (asserts! (is-none (map-get? agent-reputation { agent: agent })) ERR-AGENT-ALREADY-EXISTS)
        (map-set agent-reputation
            { agent: agent }
            {
                score: INITIAL-REPUTATION-SCORE,
                total-transactions: u0,
                successful-transactions: u0,
                disputed-transactions: u0,
                total-volume: u0,
                registration-block: block-height,
                is-active: true
            }
        )
        (ok true)
    )
)

;; Create a new escrow transaction
(define-public (create-transaction (agent principal) (amount uint))
    (let (
        (transaction-id (var-get next-transaction-id))
        (client tx-sender)
    )
        (asserts! (is-some (map-get? agent-reputation { agent: agent })) ERR-AGENT-NOT-FOUND)
        (map-set escrow-transactions
            { transaction-id: transaction-id }
            {
                agent: agent,
                client: client,
                amount: amount,
                status: "pending",
                created-block: block-height,
                completed-block: none
            }
        )
        (var-set next-transaction-id (+ transaction-id u1))
        (ok transaction-id)
    )
)

;; Complete a transaction successfully
(define-public (complete-transaction (transaction-id uint))
    (let (
        (transaction (unwrap! (map-get? escrow-transactions { transaction-id: transaction-id }) ERR-TRANSACTION-NOT-FOUND))
        (agent (get agent transaction))
        (amount (get amount transaction))
        (current-rep (unwrap! (map-get? agent-reputation { agent: agent }) ERR-AGENT-NOT-FOUND))
    )
        (asserts! (or (is-eq tx-sender agent) (is-eq tx-sender (get client transaction))) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status transaction) "pending") ERR-NOT-AUTHORIZED)

        ;; Update transaction status
        (map-set escrow-transactions
            { transaction-id: transaction-id }
            (merge transaction {
                status: "completed",
                completed-block: (some block-height)
            })
        )

        ;; Update agent reputation
        (map-set agent-reputation
            { agent: agent }
            (merge current-rep {
                total-transactions: (+ (get total-transactions current-rep) u1),
                successful-transactions: (+ (get successful-transactions current-rep) u1),
                total-volume: (+ (get total-volume current-rep) amount),
                score: (calculate-new-score current-rep true)
            })
        )
        (ok true)
    )
)

;; Report a disputed transaction
(define-public (dispute-transaction (transaction-id uint))
    (let (
        (transaction (unwrap! (map-get? escrow-transactions { transaction-id: transaction-id }) ERR-TRANSACTION-NOT-FOUND))
        (agent (get agent transaction))
        (current-rep (unwrap! (map-get? agent-reputation { agent: agent }) ERR-AGENT-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender (get client transaction)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status transaction) "pending") ERR-NOT-AUTHORIZED)

        ;; Update transaction status
        (map-set escrow-transactions
            { transaction-id: transaction-id }
            (merge transaction {
                status: "disputed",
                completed-block: (some block-height)
            })
        )

        ;; Update agent reputation
        (map-set agent-reputation
            { agent: agent }
            (merge current-rep {
                total-transactions: (+ (get total-transactions current-rep) u1),
                disputed-transactions: (+ (get disputed-transactions current-rep) u1),
                score: (calculate-new-score current-rep false)
            })
        )
        (ok true)
    )
)

;; Rate an agent after a completed transaction
(define-public (rate-agent (agent principal) (transaction-id uint) (rating uint) (comment (string-utf8 256)))
    (let (
        (client tx-sender)
        (transaction (unwrap! (map-get? escrow-transactions { transaction-id: transaction-id }) ERR-TRANSACTION-NOT-FOUND))
    )
        (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
        (asserts! (is-eq (get client transaction) client) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get agent transaction) agent) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status transaction) "completed") ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? client-ratings { client: client, agent: agent, transaction-id: transaction-id })) ERR-ALREADY-RATED)

        (map-set client-ratings
            { client: client, agent: agent, transaction-id: transaction-id }
            {
                rating: rating,
                comment: comment,
                block-height: block-height
            }
        )
        (ok true)
    )
)

;; Verify an agent (only contract owner)
(define-public (verify-agent (agent principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? agent-reputation { agent: agent })) ERR-AGENT-NOT-FOUND)
        (map-set agent-verification
            { agent: agent }
            {
                is-verified: true,
                verifier: tx-sender,
                verification-block: block-height
            }
        )
        (ok true)
    )
)

;; Deactivate an agent (only contract owner)
(define-public (deactivate-agent (agent principal))
    (let ((current-rep (unwrap! (map-get? agent-reputation { agent: agent }) ERR-AGENT-NOT-FOUND)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set agent-reputation
            { agent: agent }
            (merge current-rep { is-active: false })
        )
        (ok true)
    )
)

;; Read-only functions

;; Get agent reputation
(define-read-only (get-agent-reputation (agent principal))
    (map-get? agent-reputation { agent: agent })
)

;; Get transaction details
(define-read-only (get-transaction (transaction-id uint))
    (map-get? escrow-transactions { transaction-id: transaction-id })
)

;; Get agent verification status
(define-read-only (get-agent-verification (agent principal))
    (map-get? agent-verification { agent: agent })
)

;; Get client rating for a specific transaction
(define-read-only (get-client-rating (client principal) (agent principal) (transaction-id uint))
    (map-get? client-ratings { client: client, agent: agent, transaction-id: transaction-id })
)

;; Calculate success rate for an agent
(define-read-only (get-agent-success-rate (agent principal))
    (match (map-get? agent-reputation { agent: agent })
        rep (if (> (get total-transactions rep) u0)
                (some (/ (* (get successful-transactions rep) u100) (get total-transactions rep)))
                (some u0))
        none
    )
)

;; Check if agent is trustworthy (score >= 700)
(define-read-only (is-agent-trustworthy (agent principal))
    (match (map-get? agent-reputation { agent: agent })
        rep (and (get is-active rep) (>= (get score rep) u700))
        false
    )
)

;; Private functions

;; Helper function to get minimum of two values
(define-private (min (a uint) (b uint))
    (if (<= a b) a b)
)

;; Helper function to get maximum of two values
(define-private (max (a uint) (b uint))
    (if (>= a b) a b)
)

;; Calculate new reputation score based on transaction outcome
(define-private (calculate-new-score (current-rep (tuple (score uint) (total-transactions uint) (successful-transactions uint) (disputed-transactions uint) (total-volume uint) (registration-block uint) (is-active bool))) (successful bool))
    (let (
        (current-score (get score current-rep))
        (total-txs (get total-transactions current-rep))
        (success-rate (if (> total-txs u0)
                         (/ (* (get successful-transactions current-rep) u100) total-txs)
                         u50))
        (score-adjustment (if successful u10 u20))
        (new-score (if successful
                      (min (+ current-score score-adjustment) MAX-REPUTATION-SCORE)
                      (max (- current-score score-adjustment) MIN-REPUTATION-SCORE)))
    )
        ;; Apply additional bonuses/penalties based on success rate
        (if (> success-rate u80)
            (min (+ new-score u5) MAX-REPUTATION-SCORE)
            (if (< success-rate u20)
                (max (- new-score u10) MIN-REPUTATION-SCORE)
                new-score))
    )
)
