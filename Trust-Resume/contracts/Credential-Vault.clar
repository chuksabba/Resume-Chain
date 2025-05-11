;; Resume/CV Verification Smart Contract
;; Allows organizations to verify education, employment, and skill credentials
;; Provides a trusted verification system for recruiters and employers

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-DATA (err u104))
(define-constant ERR-EXPIRED (err u105))
(define-constant ERR-INVALID-INPUT (err u106))

;; Data structures

;; Organizational entities that can issue verifications
(define-map organizations
  { org-id: (string-ascii 64) }
  {
    name: (string-ascii 100),
    domain: (string-ascii 64),
    verified: bool,
    principal: principal
  }
)

;; Individual profiles
(define-map profiles
  { address: principal }
  {
    name: (string-ascii 100),
    email: (string-ascii 100),
    profile-uri: (optional (string-utf8 256)),
    created-at: uint,
    updated-at: uint
  }
)

;; Education credentials
(define-map education-credentials
  { 
    profile-address: principal,
    credential-id: (string-ascii 64)
  }
  {
    institution-id: (string-ascii 64),
    degree: (string-ascii 100),
    field-of-study: (string-ascii 100),
    start-date: uint,
    end-date: uint,
    verified: bool,
    verifier: (optional principal),
    verification-date: (optional uint),
    metadata-uri: (optional (string-utf8 256))
  }
)

;; Employment credentials
(define-map employment-credentials
  { 
    profile-address: principal,
    credential-id: (string-ascii 64)
  }
  {
    organization-id: (string-ascii 64),
    title: (string-ascii 100),
    description: (string-utf8 500),
    start-date: uint,
    end-date: (optional uint),
    verified: bool,
    verifier: (optional principal),
    verification-date: (optional uint),
    metadata-uri: (optional (string-utf8 256))
  }
)

;; Skills and certifications
(define-map skill-credentials
  { 
    profile-address: principal,
    credential-id: (string-ascii 64)
  }
  {
    skill-name: (string-ascii 100),
    issuer: (optional (string-ascii 64)),
    issue-date: uint,
    expiry-date: (optional uint),
    verified: bool,
    verifier: (optional principal),
    verification-date: (optional uint),
    metadata-uri: (optional (string-utf8 256))
  }
)

;; Counters for generating unique IDs
(define-data-var EDU-CREDENTIAL-NONCE uint u0)
(define-data-var EMP-CREDENTIAL-NONCE uint u0)
(define-data-var SKILL-CREDENTIAL-NONCE uint u0)

;; Helper functions

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Validate organization ID
(define-private (validate-org-id (org-id (string-ascii 64)))
  (and 
    (>= (len org-id) u1)
    (<= (len org-id) u64)
  )
)

;; Validate credential ID
(define-private (validate-credential-id (credential-id (string-ascii 64)))
  (and 
    (>= (len credential-id) u1)
    (<= (len credential-id) u64)
  )
)

;; Check if caller is the organization's principal
(define-private (is-organization-principal (org-id (string-ascii 64)))
  (if (validate-org-id org-id)
    (match (map-get? organizations { org-id: org-id })
      org (is-eq tx-sender (get principal org))
      false
    )
    false
  )
)

;; Check if caller is either contract owner or organization principal
(define-private (is-authorized-to-verify (org-id (string-ascii 64)))
  (if (validate-org-id org-id)
    (or (is-contract-owner) (is-organization-principal org-id))
    false
  )
)

;; Check if profile exists
(define-private (profile-exists (address principal))
  (is-some (map-get? profiles { address: address }))
)

;; Check if organization exists
(define-private (organization-exists (org-id (string-ascii 64)))
  (if (validate-org-id org-id)
    (is-some (map-get? organizations { org-id: org-id }))
    false
  )
)

;; Check if education credential exists
(define-private (education-credential-exists (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (is-some (map-get? education-credentials { profile-address: profile-address, credential-id: credential-id }))
    false
  )
)

;; Check if employment credential exists
(define-private (employment-credential-exists (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (is-some (map-get? employment-credentials { profile-address: profile-address, credential-id: credential-id }))
    false
  )
)

;; Check if skill credential exists
(define-private (skill-credential-exists (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (is-some (map-get? skill-credentials { profile-address: profile-address, credential-id: credential-id }))
    false
  )
)

;; Public functions

;; Register a new organization
(define-public (register-organization 
    (org-id (string-ascii 64)) 
    (name (string-ascii 100)) 
    (domain (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id org-id) ERR-INVALID-INPUT)
    (asserts! (>= (len name) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len domain) u1) ERR-INVALID-INPUT)
    
    (let ((org-data {
          name: name,
          domain: domain,
          verified: false,
          principal: tx-sender
        }))
      (if (organization-exists org-id)
        ERR-ALREADY-EXISTS
        (ok (map-set organizations { org-id: org-id } org-data))
      )
    )
  )
)

;; Verify an organization (owner only)
(define-public (verify-organization (org-id (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id org-id) ERR-INVALID-INPUT)
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    
    (match (map-get? organizations { org-id: org-id })
      org (ok (map-set organizations 
                { org-id: org-id } 
                (merge org { verified: true })))
      ERR-NOT-FOUND
    )
  )
)

;; Update organization information
(define-public (update-organization 
    (org-id (string-ascii 64)) 
    (name (string-ascii 100)) 
    (domain (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id org-id) ERR-INVALID-INPUT)
    (asserts! (>= (len name) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len domain) u1) ERR-INVALID-INPUT)
    (asserts! (is-organization-principal org-id) ERR-UNAUTHORIZED)
    
    (match (map-get? organizations { org-id: org-id })
      org (ok (map-set organizations 
                { org-id: org-id } 
                (merge org { 
                  name: name, 
                  domain: domain 
                })))
      ERR-NOT-FOUND
    )
  )
)

;; Register or update a profile
(define-public (register-profile 
    (name (string-ascii 100)) 
    (email (string-ascii 100))
    (profile-uri (optional (string-utf8 256))))
  (begin
    ;; Validate inputs
    (asserts! (>= (len name) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len email) u3) ERR-INVALID-INPUT) ;; Minimum email length
    
    (let ((current-time (default-to u0 (get-block-info? time (- block-height u1))))
          (profile-data {
           name: name,
           email: email,
           profile-uri: profile-uri,
           created-at: current-time,
           updated-at: current-time
         })
         (profile-exists-already (is-some (map-get? profiles { address: tx-sender }))))
      (if profile-exists-already
        (match (map-get? profiles { address: tx-sender })
          existing-profile 
          (ok (map-set profiles 
                { address: tx-sender } 
                (merge existing-profile { 
                  name: name, 
                  email: email, 
                  profile-uri: profile-uri,
                  updated-at: current-time
                })))
          ERR-NOT-FOUND
        )
        (ok (map-set profiles { address: tx-sender } profile-data))
      )
    )
  )
)

;; Add an education credential to a profile
(define-public (add-education-credential
    (institution-id (string-ascii 64))
    (degree (string-ascii 100))
    (field-of-study (string-ascii 100))
    (start-date uint)
    (end-date uint)
    (metadata-uri (optional (string-utf8 256))))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id institution-id) ERR-INVALID-INPUT)
    (asserts! (>= (len degree) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len field-of-study) u1) ERR-INVALID-INPUT)
    
    ;; Validate profile existence
    (asserts! (profile-exists tx-sender) ERR-NOT-FOUND)
    ;; Validate dates
    (asserts! (<= start-date end-date) ERR-INVALID-DATA)
    
    ;; Create a simple unique credential ID
    (let ((nonce (var-get EDU-CREDENTIAL-NONCE))
          ;; Create a credential ID and ensure it's within the 64 character limit
          (credential-id (unwrap-panic 
                          (as-max-len? 
                            (concat "EDU-" 
                                   (concat (unwrap-panic (as-max-len? institution-id u20)) 
                                           (concat "-" (unwrap-panic (as-max-len? degree u8)))))
                            u64)))
          (credential-data {
            institution-id: institution-id,
            degree: degree,
            field-of-study: field-of-study,
            start-date: start-date,
            end-date: end-date,
            verified: false,
            verifier: none,
            verification-date: none,
            metadata-uri: metadata-uri
          }))
      ;; Increment nonce
      (var-set EDU-CREDENTIAL-NONCE (+ nonce u1))
      
      ;; Validate credential ID
      (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
      
      (ok (map-set education-credentials 
            { profile-address: tx-sender, credential-id: credential-id } 
            credential-data))
    )
  )
)

;; Add an employment credential to a profile
(define-public (add-employment-credential
    (organization-id (string-ascii 64))
    (title (string-ascii 100))
    (description (string-utf8 500))
    (start-date uint)
    (end-date (optional uint))
    (metadata-uri (optional (string-utf8 256))))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id organization-id) ERR-INVALID-INPUT)
    (asserts! (>= (len title) u1) ERR-INVALID-INPUT)
    (asserts! (>= (len description) u1) ERR-INVALID-INPUT)
    
    ;; Validate profile existence
    (asserts! (profile-exists tx-sender) ERR-NOT-FOUND)
    ;; Validate dates if end date is provided
    (match end-date
      end (asserts! (<= start-date end) ERR-INVALID-DATA)
      true
    )
    
    ;; Create a simple unique credential ID
    (let ((nonce (var-get EMP-CREDENTIAL-NONCE))
          ;; Create a credential ID and ensure it's within the 64 character limit
          (credential-id (unwrap-panic 
                          (as-max-len? 
                            (concat "EMP-" 
                                   (concat (unwrap-panic (as-max-len? organization-id u20)) 
                                           (concat "-" (unwrap-panic (as-max-len? title u8)))))
                            u64)))
          (credential-data {
            organization-id: organization-id,
            title: title,
            description: description,
            start-date: start-date,
            end-date: end-date,
            verified: false,
            verifier: none,
            verification-date: none,
            metadata-uri: metadata-uri
          }))
      ;; Increment nonce
      (var-set EMP-CREDENTIAL-NONCE (+ nonce u1))
      
      ;; Validate credential ID
      (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
      
      (ok (map-set employment-credentials 
            { profile-address: tx-sender, credential-id: credential-id } 
            credential-data))
    )
  )
)

;; Add a skill credential to a profile
(define-public (add-skill-credential
    (skill-name (string-ascii 100))
    (issuer (optional (string-ascii 64)))
    (issue-date uint)
    (expiry-date (optional uint))
    (metadata-uri (optional (string-utf8 256))))
  (begin
    ;; Validate inputs
    (asserts! (>= (len skill-name) u1) ERR-INVALID-INPUT)
    
    ;; Validate issuer if provided
    (match issuer
      issuer-id (begin
                  (asserts! (validate-org-id issuer-id) ERR-INVALID-INPUT)
                  (asserts! (organization-exists issuer-id) ERR-NOT-FOUND))
      true
    )
    
    ;; Validate profile existence
    (asserts! (profile-exists tx-sender) ERR-NOT-FOUND)
    ;; Validate dates if expiry date is provided
    (match expiry-date
      expiry (asserts! (<= issue-date expiry) ERR-INVALID-DATA)
      true
    )
    
    ;; Create a simple unique credential ID
    (let ((nonce (var-get SKILL-CREDENTIAL-NONCE))
          (issuer-part (match issuer
                          some-issuer (unwrap-panic (as-max-len? some-issuer u15))
                          "none"))
          ;; Create a credential ID and ensure it's within the 64 character limit
          (credential-id (unwrap-panic 
                          (as-max-len? 
                            (concat "SKILL-" 
                                   (concat issuer-part 
                                           (concat "-" (unwrap-panic (as-max-len? skill-name u15)))))
                            u64)))
          (credential-data {
            skill-name: skill-name,
            issuer: issuer,
            issue-date: issue-date,
            expiry-date: expiry-date,
            verified: false,
            verifier: none,
            verification-date: none,
            metadata-uri: metadata-uri
          }))
      ;; Increment nonce
      (var-set SKILL-CREDENTIAL-NONCE (+ nonce u1))
      
      ;; Validate credential ID
      (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
      
      (ok (map-set skill-credentials 
            { profile-address: tx-sender, credential-id: credential-id } 
            credential-data))
    )
  )
)

;; Verify an education credential
(define-public (verify-education-credential
    (profile-address principal)
    (credential-id (string-ascii 64))
    (institution-id (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id institution-id) ERR-INVALID-INPUT)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (is-authorized-to-verify institution-id) ERR-UNAUTHORIZED)
    (asserts! (is-verified-organization institution-id) ERR-UNAUTHORIZED)
    (asserts! (education-credential-exists profile-address credential-id) ERR-NOT-FOUND)
    
    (match (map-get? education-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (asserts! (is-eq (get institution-id cred) institution-id) ERR-UNAUTHORIZED)
        (ok (map-set education-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: true, 
                verifier: (some tx-sender),
                verification-date: (some (default-to u0 (get-block-info? time (- block-height u1))))
              })))
      )
      ERR-NOT-FOUND
    )
  )
)

;; Verify an employment credential
(define-public (verify-employment-credential
    (profile-address principal)
    (credential-id (string-ascii 64))
    (organization-id (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id organization-id) ERR-INVALID-INPUT)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (is-authorized-to-verify organization-id) ERR-UNAUTHORIZED)
    (asserts! (is-verified-organization organization-id) ERR-UNAUTHORIZED)
    (asserts! (employment-credential-exists profile-address credential-id) ERR-NOT-FOUND)
    
    (match (map-get? employment-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (asserts! (is-eq (get organization-id cred) organization-id) ERR-UNAUTHORIZED)
        (ok (map-set employment-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: true, 
                verifier: (some tx-sender),
                verification-date: (some (default-to u0 (get-block-info? time (- block-height u1))))
              })))
      )
      ERR-NOT-FOUND
    )
  )
)

;; Verify a skill credential
(define-public (verify-skill-credential
    (profile-address principal)
    (credential-id (string-ascii 64))
    (org-id (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id org-id) ERR-INVALID-INPUT)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (is-authorized-to-verify org-id) ERR-UNAUTHORIZED)
    (asserts! (is-verified-organization org-id) ERR-UNAUTHORIZED)
    (asserts! (skill-credential-exists profile-address credential-id) ERR-NOT-FOUND)
    
    (match (map-get? skill-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (match (get issuer cred)
          issuer-id (asserts! (is-eq issuer-id org-id) ERR-UNAUTHORIZED)
          true
        )
        ;; Check if skill is expired
        (match (get expiry-date cred)
          expiry (asserts! (> expiry (default-to u0 (get-block-info? time (- block-height u1)))) ERR-EXPIRED)
          true
        )
        (ok (map-set skill-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: true, 
                verifier: (some tx-sender),
                verification-date: (some (default-to u0 (get-block-info? time (- block-height u1))))
              })))
      )
      ERR-NOT-FOUND
    )
  )
)

;; Revoke a verification (for organizations or contract owner)
(define-public (revoke-education-verification
    (profile-address principal)
    (credential-id (string-ascii 64))
    (institution-id (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id institution-id) ERR-INVALID-INPUT)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (or (is-contract-owner) (is-organization-principal institution-id)) ERR-UNAUTHORIZED)
    (asserts! (education-credential-exists profile-address credential-id) ERR-NOT-FOUND)
    
    (match (map-get? education-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (asserts! (is-eq (get institution-id cred) institution-id) ERR-UNAUTHORIZED)
        (asserts! (get verified cred) ERR-INVALID-DATA) ;; Can only revoke if currently verified
        (ok (map-set education-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: false, 
                verifier: none,
                verification-date: none 
              })))
      )
      ERR-NOT-FOUND
    )
  )
)

(define-public (revoke-employment-verification
    (profile-address principal)
    (credential-id (string-ascii 64))
    (organization-id (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id organization-id) ERR-INVALID-INPUT)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (or (is-contract-owner) (is-organization-principal organization-id)) ERR-UNAUTHORIZED)
    (asserts! (employment-credential-exists profile-address credential-id) ERR-NOT-FOUND)
    
    (match (map-get? employment-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (asserts! (is-eq (get organization-id cred) organization-id) ERR-UNAUTHORIZED)
        (asserts! (get verified cred) ERR-INVALID-DATA) ;; Can only revoke if currently verified
        (ok (map-set employment-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: false, 
                verifier: none,
                verification-date: none 
              })))
      )
      ERR-NOT-FOUND
    )
  )
)

(define-public (revoke-skill-verification
    (profile-address principal)
    (credential-id (string-ascii 64))
    (org-id (string-ascii 64)))
  (begin
    ;; Validate inputs
    (asserts! (validate-org-id org-id) ERR-INVALID-INPUT)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (or (is-contract-owner) (is-organization-principal org-id)) ERR-UNAUTHORIZED)
    (asserts! (skill-credential-exists profile-address credential-id) ERR-NOT-FOUND)
    
    (match (map-get? skill-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (match (get issuer cred)
          issuer-id (asserts! (is-eq issuer-id org-id) ERR-UNAUTHORIZED)
          true
        )
        (asserts! (get verified cred) ERR-INVALID-DATA) ;; Can only revoke if currently verified
        (ok (map-set skill-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: false, 
                verifier: none,
                verification-date: none 
              })))
      )
      ERR-NOT-FOUND
    )
  )
)

;; Read-only functions

;; Get profile information
(define-read-only (get-profile (address principal))
  (map-get? profiles { address: address })
)

;; Get organization information
(define-read-only (get-organization (org-id (string-ascii 64)))
  (if (validate-org-id org-id)
    (map-get? organizations { org-id: org-id })
    none
  )
)

;; Get education credential information
(define-read-only (get-education-credential (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (map-get? education-credentials { profile-address: profile-address, credential-id: credential-id })
    none
  )
)

;; Get employment credential information
(define-read-only (get-employment-credential (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (map-get? employment-credentials { profile-address: profile-address, credential-id: credential-id })
    none
  )
)

;; Get skill credential information
(define-read-only (get-skill-credential (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (map-get? skill-credentials { profile-address: profile-address, credential-id: credential-id })
    none
  )
)

;; Verify if a credential is valid and not expired
(define-read-only (is-education-credential-valid (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (match (map-get? education-credentials { profile-address: profile-address, credential-id: credential-id })
      cred (get verified cred)
      false
    )
    false
  )
)

(define-read-only (is-employment-credential-valid (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (match (map-get? employment-credentials { profile-address: profile-address, credential-id: credential-id })
      cred (get verified cred)
      false
    )
    false
  )
)

(define-read-only (is-skill-credential-valid (profile-address principal) (credential-id (string-ascii 64)))
  (if (validate-credential-id credential-id)
    (match (map-get? skill-credentials { profile-address: profile-address, credential-id: credential-id })
      cred 
      (and 
        (get verified cred)
        (match (get expiry-date cred)
          expiry (> expiry (default-to u0 (get-block-info? time (- block-height u1))))
          true
        )
      )
      false
    )
    false
  )
)

;; Check if principal is a verified organization
(define-read-only (is-verified-organization (org-id (string-ascii 64)))
  (if (validate-org-id org-id)
    (match (map-get? organizations { org-id: org-id })
      org (get verified org)
      false
    )
    false
  )
)