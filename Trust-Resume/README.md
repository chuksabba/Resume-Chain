# Resume/CV Verification Smart Contract

A Clarity smart contract for creating a decentralized, trustless system to verify education, employment, and skill credentials on the Stacks blockchain.

## Overview

This smart contract provides a secure and transparent way to verify professional credentials on a blockchain. It allows:

- **Individuals** to create profiles and add their education, employment, and skill credentials
- **Organizations** (schools, employers, certification bodies) to verify these credentials
- **Recruiters and employers** to check the authenticity of a candidate's claims

By leveraging blockchain technology, this system creates an immutable record of verified credentials that cannot be forged or tampered with, reducing fraud in the hiring process.

## Key Features

- **Profile Management**: Users can create and update their professional profiles
- **Credential Types**: Support for education, employment history, and skills/certifications
- **Trusted Organizations**: Only verified organizations can validate credentials
- **Verification Lifecycle**: Add, verify, and revoke verifications as needed
- **Expiration Support**: Skills and certifications can have expiration dates
- **Metadata Support**: Optional URIs for additional documentation

## Contract Architecture

The smart contract uses the following data structures:

- `organizations`: Entities that can issue verifications
- `profiles`: Individual user profiles with basic information
- `education-credentials`: Academic qualifications and degrees
- `employment-credentials`: Work history and positions
- `skill-credentials`: Skills, certifications, and technical competencies

## Function Guide

### Organization Management

- `register-organization`: Register a new organization
- `verify-organization`: Contract owner verifies a legitimate organization
- `update-organization`: Update an organization's information
- `is-verified-organization`: Check if an organization is verified

### Profile Management

- `register-profile`: Create or update a user profile
- `get-profile`: Retrieve profile information

### Credential Management

#### Education Credentials
- `add-education-credential`: Add education credential to a profile
- `verify-education-credential`: Organization verifies an education claim
- `revoke-education-verification`: Remove verification from a credential
- `get-education-credential`: Retrieve education credential details
- `is-education-credential-valid`: Check if credential is verified

#### Employment Credentials
- `add-employment-credential`: Add employment credential to a profile
- `verify-employment-credential`: Organization verifies employment
- `revoke-employment-verification`: Remove verification from a credential
- `get-employment-credential`: Retrieve employment credential details
- `is-employment-credential-valid`: Check if credential is verified

#### Skill Credentials
- `add-skill-credential`: Add skill or certification to a profile
- `verify-skill-credential`: Organization verifies a skill
- `revoke-skill-verification`: Remove verification from a skill
- `get-skill-credential`: Retrieve skill credential details
- `is-skill-credential-valid`: Check if skill is verified and not expired

## Usage Examples

### Creating a Profile

```clarity
(contract-call? .resume-verifier register-profile 
  "John Doe" 
  "john@example.com"
  (some "https://my-profile.com/john")
)
```

### Adding Education Credential

```clarity
(contract-call? .resume-verifier add-education-credential
  "stanford-university"
  "Bachelor of Science"
  "Computer Science"
  u1577836800  ;; Jan 1, 2020
  u1609459200  ;; Jan 1, 2021
  (some "https://ipfs.io/ipfs/QmXyz...")
)
```

### University Verifying a Degree

```clarity
;; Called by the university's principal
(contract-call? .resume-verifier verify-education-credential
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; Student's address
  "credential-123456"                          ;; Credential ID
  "stanford-university"                        ;; Institution ID
)
```

### Checking Credential Validity

```clarity
(contract-call? .resume-verifier is-education-credential-valid
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; Student's address
  "credential-123456"                          ;; Credential ID
)
```

## Error Codes

- `u100`: Action restricted to contract owner
- `u101`: Requested item not found
- `u102`: Unauthorized action
- `u103`: Item already exists
- `u104`: Invalid data provided
- `u105`: Credential has expired

## Security Considerations

- Only the contract owner can verify organizations
- Organizations can only verify credentials related to them
- Credentials cannot be modified once added, only verification status can change
- Profiles can only be updated by the owner
- Time-based expiration for skill credentials
- Verification trail with timestamps and verifier information