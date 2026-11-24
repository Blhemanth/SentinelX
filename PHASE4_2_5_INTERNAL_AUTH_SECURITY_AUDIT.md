# SentinelX — Phase 4.2.5: Internal Service Authentication & Trust Boundary Security Audit

**Document Version:** 1.0.0  
**Date:** 2026-11-22  
**Author:** Principal Application Security Engineer & Backend Architect  
**Classification:** Safety-Critical Application Security Audit  
**Scope:** Express Backend, Internal Service Authentication, Trust Boundaries, REST Ingestion Security  

---

## 1. Executive Summary

During the Phase 4.2.4 security review, a critical architectural vulnerability was identified in how the Node.js/Express backend established trust for internal service operations—specifically for verified server-side audio provenance in Acoustic SOS ingestion.

The existing implementation permitted two severe anti-patterns:
1. **Insecure Static Marker Headers & Hardcoded Fallbacks:** The server trusted unauthenticated plain HTTP headers such as `x-sentinelx-internal-source: server_audio_verifier` and relied on a static fallback secret (`sentinelx_internal_audio_token_secure`) whenever `process.env.INTERNAL_SERVICE_KEY` was undefined.
2. **Untrusted Client Request Injection:** The server allowed client payloads to inject internal state properties (`req.isServerVerifiedAudio = true` or `body.isServerVerifiedAudio = true`), which could bypass emergency escalation controls if malicious actors manipulated request headers or bodies.

**Phase 4.2.5 eliminates these vulnerabilities completely.** A hardened, cryptographic service-to-service authentication architecture has been implemented based on **HMAC-SHA256 tokens**, **timestamp freshness windows ($\pm 60$ seconds)**, **sliding memory nonce caches for replay protection**, and **mandatory fail-closed startup validation in production environments**.

---

## 2. Vulnerability Analysis & Threat Modeling

### 2.1 The Static Header & Default Key Anti-Pattern (CWE-287 / CWE-798)
In previous phases, the backend checked internal service authenticity using:
```javascript
// INSECURE LEGACY IMPLEMENTATION
const internalKey = process.env.INTERNAL_SERVICE_KEY || 'sentinelx_internal_audio_token_secure';
const authHeader = req.headers['x-sentinelx-internal-token'] || req.headers['x-sentinelx-internal-source'];
if (authHeader === internalKey || authHeader === 'server_audio_verifier') {
  req.isServerVerifiedAudio = true;
}
```
**Vulnerability Impact:**
- Any untrusted HTTP client (such as a compromised external API client or browser) that included `x-sentinelx-internal-source: server_audio_verifier` would be treated as an authoritative internal microservice.
- Deployments running without an explicitly configured `INTERNAL_SERVICE_KEY` environment variable defaulted to a publicly known hardcoded string, allowing attackers to forge internal authentication headers trivially.

### 2.2 Client Property Injection & State Pollution (CWE-20 / CWE-915)
In the Express request handling chain:
- Malicious clients could send `{ "isServerVerifiedAudio": true }` or `{ "req_isServerVerifiedAudio": true }` in the JSON request body.
- If middleware attached body properties to request objects blindly, downstream controllers could misinterpret client input as authenticated internal server provenance.

### 2.3 Replay Attacks Against Stateless Tokens (CWE-294)
- Without unique per-request nonces and freshness checks, a captured internal service token could be replayed indefinitely by an adversary with network visibility, allowing unauthorized automated emergency escalation.

---

## 3. Cryptographic Internal Service Authentication Specification

To resolve these vulnerabilities, a dedicated internal authentication module was engineered in `backend/src/middleware/internalAuth.js`.

### 3.1 Token Format Specification
All internal service tokens adhere to a canonical 5-part period-delimited structure:
$$\text{Token} = \texttt{v1}.\langle\text{serviceId}\rangle.\langle\text{timestamp}\rangle.\langle\text{nonce}\rangle.\langle\text{signature}\rangle$$

| Component | Type | Description | Security Requirements |
| :--- | :--- | :--- | :--- |
| **`v1`** | String | Protocol version identifier | Must match supported protocol version. |
| **`serviceId`** | String | Identifier of issuing internal microservice | Must match trusted internal service taxonomy (e.g. `sentinelx-audio-verifier`, `sentinelx-ml-engine`). |
| **`timestamp`** | Integer | Unix epoch millisecond timestamp ($t_{req}$) | Must satisfy $|t_{now} - t_{req}| \le 60{,}000\text{ ms}$ (60-second sliding freshness window). |
| **`nonce`** | String | Cryptographically random UUID v4 | Must be unique per request; checked against sliding replay cache. |
| **`signature`** | Hex String | HMAC-SHA256 signature | Computed over payload `serviceId:timestamp:nonce` using `INTERNAL_SERVICE_KEY`. |

### 3.2 Cryptographic Signature Generation
The internal service computes:
$$\text{payload} = \text{serviceId} \parallel \texttt{":"} \parallel \text{timestamp} \parallel \texttt{":"} \parallel \text{nonce}$$
$$\text{signature} = \text{HMAC-SHA256}(\text{key} = \text{INTERNAL\_SERVICE\_KEY}, \text{data} = \text{payload})$$

### 3.3 Verification Pipeline
When receiving an internal request (via header `x-sentinelx-service-auth` or `x-sentinelx-internal-token`), `verifyInternalServiceToken` executes:
1. **Format Validation:** Verifies token decomposes into exactly 5 components and starts with `v1`.
2. **Freshness Verification:** Computes $\Delta t = |t_{now} - t_{req}|$. If $\Delta t > 60{,}000\text{ ms}$, rejects immediately (`Token expired or clock skew exceeded 60s`).
3. **Replay Cache Verification:** Queries an in-memory sliding cache of recently processed nonces. If the nonce exists, rejects immediately (`Replay attack detected`). If absent, registers the nonce with an expiration TTL equal to the remaining freshness window.
4. **Timing-Safe Cryptographic Signature Verification:** Computes the expected HMAC-SHA256 signature and validates using `crypto.timingSafeEqual()` to eliminate timing side-channel attacks.
5. **Service ID Assertion:** Verifies that `serviceId` matches expected service requirements.

---

## 4. Production Security & Fail-Closed Startup Enforcement

The internal authentication subsystem enforces strict configuration safety via `validateInternalServiceConfig()`:

```javascript
const INSECURE_DEFAULT_SERVICE_KEYS = [
  'sentinelx_internal_audio_token_secure',
  'sentinelx_internal_default_secret_key',
  'sentinelx_default_internal_service_key',
  'sentinelx_internal_key_development_only',
  'change_this_to_a_secure_service_key_in_production',
  'sentinelx_internal_dev_test_key_32_chars_min',
];
```

### 4.1 Production Fail-Closed Rules (`NODE_ENV === 'production'`)
1. **Mandatory Secret:** If `INTERNAL_SERVICE_KEY` is undefined or null, Express throws a fatal error: `[Internal Auth Fatal] Production environment requires INTERNAL_SERVICE_KEY with minimum 32 characters.`
2. **Minimum Length:** If `INTERNAL_SERVICE_KEY.length < 32`, Express throws a fatal error and refuses to start.
3. **Default Key Blacklist:** If `INTERNAL_SERVICE_KEY` matches any known development secret or default string, Express throws a fatal error: `[Internal Auth Fatal] Insecure default INTERNAL_SERVICE_KEY detected in production environment.`

### 4.2 Development Environment Protections
In non-production environments (`development`, `test`), if `INTERNAL_SERVICE_KEY` is missing or insecure, the server logs a prominent console warning:
`[Internal Auth Warning] INTERNAL_SERVICE_KEY is unset or using a default key in non-production environment.`

---

## 5. Acoustic SOS Trust Policy & Emergency Boundary Hardening

### 5.1 Elimination of Insecure Plain Marker Headers
`logs.controller.js` and `internalAuth.js` have been stripped of all trust in plain headers:
- `x-sentinelx-internal-source` is **ignored**.
- Direct client injection of `req.isServerVerifiedAudio` or body fields is **stripped**:
  ```javascript
  delete payload.severity;
  delete payload.isEmergencyEligible;
  delete payload.isServerVerifiedAudio;
  delete payload.req_isServerVerifiedAudio;
  ```

### 5.2 Strict Ingestion Policy for Acoustic SOS
When an incident is submitted via `POST /api/logs`:
```javascript
if (payload.detectionSource === 'acoustic_sos') {
  const isGenuineAudioVerifier = isInternalServiceAuthenticated && 
                                authenticatedServiceId === 'sentinelx-audio-verifier';
  if (!isGenuineAudioVerifier) {
    // Untrusted or non-verifier claim: sanitize to manual_entry and low_confidence_review
    payload.detectionSource = 'manual_entry';
    payload.detectionStatus = 'low_confidence_review';
  }
}
```
**Operational Safety Result:**
- Client-reported distress (from mobile, web, or CAD tools) is automatically sanitized to `manual_entry` with `severity: 'low'`, requiring human operator review before police dispatch can occur.
- Automated `acoustic_sos` emergency escalation is strictly reserved for authenticated internal audio microservices bearing cryptographic provenance (`sentinelx-audio-verifier`).

---

## 6. Audit Conclusion & Compliance Status

| Audit Checkpoint | Pre-Phase 4.2.5 State | Phase 4.2.5 Hardened State | Compliance Status |
| :--- | :--- | :--- | :---: |
| **Internal Auth Transport** | Plain marker header / static string | Cryptographic HMAC-SHA256 token | **PASS** |
| **Token Freshness** | None (indefinite lifespan) | 60-second sliding timestamp window | **PASS** |
| **Replay Protection** | None (replay vulnerable) | In-memory sliding nonce cache | **PASS** |
| **Side-Channel Timing** | Vulnerable to string comparison | `crypto.timingSafeEqual` enforced | **PASS** |
| **Production Fail-Closed** | Permissive fallback | Fatal process termination if $<32$ chars | **PASS** |
| **Client Property Injection** | Possible via body / req props | Explicit deletion & middleware sanitization | **PASS** |
| **Acoustic SOS Authorization** | Client-spoofable via string fields | Cryptographically gated to verified internal service | **PASS** |

The SentinelX internal service authentication architecture is verified as **robust, fail-closed, and compliant with safety-critical defense-in-depth principles**.
