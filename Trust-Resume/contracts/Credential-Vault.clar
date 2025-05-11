;; Resume/CV Verification Smart Contract
;; Allows organizations to verify education, employment, and skill credentials
;; Provides a trusted verification system for recruiters and employers

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-data (err u104))
(define-constant err-expired (err u105))

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
(define-data-var edu-credential-nonce uint u0)
(define-data-var emp-credential-nonce uint u0)
(define-data-var skill-credential-nonce uint u0)

;; Helper functions

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

;; Check if caller is the organization's principal
(define-private (is-organization-principal (org-id (string-ascii 64)))
  (match (map-get? organizations { org-id: org-id })
    org (is-eq tx-sender (get principal org))
    false
  )
)

;; Check if caller is either contract owner or organization principal
(define-private (is-authorized-to-verify (org-id (string-ascii 64)))
  (or (is-contract-owner) (is-organization-principal org-id))
)

;; Check if profile exists
(define-private (profile-exists (address principal))
  (is-some (map-get? profiles { address: address }))
)

;; Check if organization exists
(define-private (organization-exists (org-id (string-ascii 64)))
  (is-some (map-get? organizations { org-id: org-id }))
)

;; Public functions

;; Register a new organization
(define-public (register-organization 
    (org-id (string-ascii 64)) 
    (name (string-ascii 100)) 
    (domain (string-ascii 64)))
  (let ((org-data {
        name: name,
        domain: domain,
        verified: false,
        principal: tx-sender
      }))
    (if (organization-exists org-id)
      err-already-exists
      (ok (map-set organizations { org-id: org-id } org-data))
    )
  )
)

;; Verify an organization (owner only)
(define-public (verify-organization (org-id (string-ascii 64)))
  (if (is-contract-owner)
    (match (map-get? organizations { org-id: org-id })
      org (ok (map-set organizations 
                { org-id: org-id } 
                (merge org { verified: true })))
      err-not-found
    )
    err-owner-only
  )
)

;; Update organization information
(define-public (update-organization 
    (org-id (string-ascii 64)) 
    (name (string-ascii 100)) 
    (domain (string-ascii 64)))
  (if (is-organization-principal org-id)
    (match (map-get? organizations { org-id: org-id })
      org (ok (map-set organizations 
                { org-id: org-id } 
                (merge org { 
                  name: name, 
                  domain: domain 
                })))
      err-not-found
    )
    err-unauthorized
  )
)

;; Register or update a profile
(define-public (register-profile 
    (name (string-ascii 100)) 
    (email (string-ascii 100))
    (profile-uri (optional (string-utf8 256))))
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
        err-not-found
      )
      (ok (map-set profiles { address: tx-sender } profile-data))
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
    ;; Validate profile existence
    (asserts! (profile-exists tx-sender) err-not-found)
    ;; Validate dates
    (asserts! (<= start-date end-date) err-invalid-data)
    
    ;; Create a simple unique credential ID
    (let ((nonce (var-get edu-credential-nonce))
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
      (var-set edu-credential-nonce (+ nonce u1))
      
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
    ;; Validate profile existence
    (asserts! (profile-exists tx-sender) err-not-found)
    ;; Validate dates if end date is provided
    (match end-date
      end (asserts! (<= start-date end) err-invalid-data)
      true
    )
    
    ;; Create a simple unique credential ID
    (let ((nonce (var-get emp-credential-nonce))
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
      (var-set emp-credential-nonce (+ nonce u1))
      
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
    ;; Validate profile existence
    (asserts! (profile-exists tx-sender) err-not-found)
    ;; Validate dates if expiry date is provided
    (match expiry-date
      expiry (asserts! (<= issue-date expiry) err-invalid-data)
      true
    )
    ;; Validate issuer if provided
    (match issuer
      issuer-id (asserts! (organization-exists issuer-id) err-not-found)
      true
    )
    
    ;; Create a simple unique credential ID
    (let ((nonce (var-get skill-credential-nonce))
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
      (var-set skill-credential-nonce (+ nonce u1))
      
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
    (asserts! (is-authorized-to-verify institution-id) err-unauthorized)
    (asserts! (is-verified-organization institution-id) err-unauthorized)
    
    (match (map-get? education-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (asserts! (is-eq (get institution-id cred) institution-id) err-unauthorized)
        (ok (map-set education-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: true, 
                verifier: (some tx-sender),
                verification-date: (some (default-to u0 (get-block-info? time (- block-height u1))))
              })))
      )
      err-not-found
    )
  )
)

;; Verify an employment credential
(define-public (verify-employment-credential
    (profile-address principal)
    (credential-id (string-ascii 64))
    (organization-id (string-ascii 64)))
  (begin
    (asserts! (is-authorized-to-verify organization-id) err-unauthorized)
    (asserts! (is-verified-organization organization-id) err-unauthorized)
    
    (match (map-get? employment-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (asserts! (is-eq (get organization-id cred) organization-id) err-unauthorized)
        (ok (map-set employment-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: true, 
                verifier: (some tx-sender),
                verification-date: (some (default-to u0 (get-block-info? time (- block-height u1))))
              })))
      )
      err-not-found
    )
  )
)

;; Verify a skill credential
(define-public (verify-skill-credential
    (profile-address principal)
    (credential-id (string-ascii 64))
    (org-id (string-ascii 64)))
  (begin
    (asserts! (is-authorized-to-verify org-id) err-unauthorized)
    (asserts! (is-verified-organization org-id) err-unauthorized)
    
    (match (map-get? skill-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (match (get issuer cred)
          issuer-id (asserts! (is-eq issuer-id org-id) err-unauthorized)
          true
        )
        ;; Check if skill is expired
        (match (get expiry-date cred)
          expiry (asserts! (> expiry (default-to u0 (get-block-info? time (- block-height u1)))) err-expired)
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
      err-not-found
    )
  )
)

;; Revoke a verification (for organizations or contract owner)
(define-public (revoke-education-verification
    (profile-address principal)
    (credential-id (string-ascii 64))
    (institution-id (string-ascii 64)))
  (begin
    (asserts! (or (is-contract-owner) (is-organization-principal institution-id)) err-unauthorized)
    
    (match (map-get? education-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (asserts! (is-eq (get institution-id cred) institution-id) err-unauthorized)
        (asserts! (get verified cred) err-invalid-data) ;; Can only revoke if currently verified
        (ok (map-set education-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: false, 
                verifier: none,
                verification-date: none 
              })))
      )
      err-not-found
    )
  )
)

(define-public (revoke-employment-verification
    (profile-address principal)
    (credential-id (string-ascii 64))
    (organization-id (string-ascii 64)))
  (begin
    (asserts! (or (is-contract-owner) (is-organization-principal organization-id)) err-unauthorized)
    
    (match (map-get? employment-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (asserts! (is-eq (get organization-id cred) organization-id) err-unauthorized)
        (asserts! (get verified cred) err-invalid-data) ;; Can only revoke if currently verified
        (ok (map-set employment-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: false, 
                verifier: none,
                verification-date: none 
              })))
      )
      err-not-found
    )
  )
)

(define-public (revoke-skill-verification
    (profile-address principal)
    (credential-id (string-ascii 64))
    (org-id (string-ascii 64)))
  (begin
    (asserts! (or (is-contract-owner) (is-organization-principal org-id)) err-unauthorized)
    
    (match (map-get? skill-credentials 
            { profile-address: profile-address, credential-id: credential-id })
      cred 
      (begin
        (match (get issuer cred)
          issuer-id (asserts! (is-eq issuer-id org-id) err-unauthorized)
          true
        )
        (asserts! (get verified cred) err-invalid-data) ;; Can only revoke if currently verified
        (ok (map-set skill-credentials 
              { profile-address: profile-address, credential-id: credential-id } 
              (merge cred { 
                verified: false, 
                verifier: none,
                verification-date: none 
              })))
      )
      err-not-found
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
  (map-get? organizations { org-id: org-id })
)

;; Get education credential information
(define-read-only (get-education-credential (profile-address principal) (credential-id (string-ascii 64)))
  (map-get? education-credentials { profile-address: profile-address, credential-id: credential-id })
)

;; Get employment credential information
(define-read-only (get-employment-credential (profile-address principal) (credential-id (string-ascii 64)))
  (map-get? employment-credentials { profile-address: profile-address, credential-id: credential-id })
)

;; Get skill credential information
(define-read-only (get-skill-credential (profile-address principal) (credential-id (string-ascii 64)))
  (map-get? skill-credentials { profile-address: profile-address, credential-id: credential-id })
)

;; Verify if a credential is valid and not expired
(define-read-only (is-education-credential-valid (profile-address principal) (credential-id (string-ascii 64)))
  (match (map-get? education-credentials { profile-address: profile-address, credential-id: credential-id })
    cred (get verified cred)
    false
  )
)

(define-read-only (is-employment-credential-valid (profile-address principal) (credential-id (string-ascii 64)))
  (match (map-get? employment-credentials { profile-address: profile-address, credential-id: credential-id })
    cred (get verified cred)
    false
  )
)

(define-read-only (is-skill-credential-valid (profile-address principal) (credential-id (string-ascii 64)))
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
)

;; Check if principal is a verified organization
(define-read-only (is-verified-organization (org-id (string-ascii 64)))
  (match (map-get? organizations { org-id: org-id })
    org (get verified org)
    false
  )
)