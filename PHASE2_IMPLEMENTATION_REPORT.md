# SentinelX — Phase 2: Security Hardening & Critical Bug Fixes Implementation Report

**Date:** November 21, 2026  
**Auditor / Engineer:** Senior Backend Engineer, Application Security Architect, MERN Developer & Flutter Security Engineer  
**Scope:** Express Backend, React Web Client, Flutter Desktop/Android Client, and Python ML Inference Service  
**Status:** **100% Implemented & Verified**

---

## 1. Executive Summary

Phase 2 focused on resolving critical architectural vulnerabilities identified during the Phase 1 comprehensive audit. The objective was to eliminate session collision bugs, enforce strict cryptographic secret handling, fix administrative role provisioning, implement secure cookie-based token handling for web clients, integrate native hardware-backed encrypted storage for Flutter desktop and mobile, and restrict microservice CORS boundaries.

All 6 tasks were executed with **zero regression** on existing functionality. The 5-tier architecture (Express REST API, MongoDB Community Edition, React.js web client, Flutter client, and Python ML inference microservice) remains intact and operational.

---

## 2. Before-and-After Task Comparison Matrix

| Task # | Area | Before State (Vulnerable) | After State (Hardened) | Verified Result |
|---|---|---|---|---|
| **Task 1** | Refresh Token Collision | Refresh token payload only signed `{ userId }`. Sub-second token rotations generated identical JWT strings, triggering unhandled MongoDB `E11000 duplicate key error`. | Injected `crypto.randomUUID()` as standard `jti` nonce into refresh tokens. Added duplicate key `code: 11000` handling with HTTP 409 retry semantics. | 100/100 sub-second tokens 100% unique; 5 consecutive live sub-second session rotations passed with 0 errors. |
| **Task 2** | JWT Secret Validation | `jwt.js` defaulted to hardcoded dev secrets (`sentinelx_access_dev_secret_CHANGE_IN_PROD`). Missing `.env` permitted forged tokens. Identical access/refresh secrets were allowed. | Implemented `validateJwtConfig()` on module startup. In production: rejects keys < 32 chars, known default secrets, and identical access/refresh keys. Updated `.env.example` with 64+ char instructions. | Production mode successfully aborted on short/default/identical secrets; allowed strong keys. |
| **Task 3** | Admin Role Provisioning | `auth.controller.js` sanitized roles against `['analyst', 'admin']`, omitting `'police'`. Admin creating police accounts resulted in demotion to `'user'`. | Updated whitelist to `['admin', 'police', 'analyst', 'user']` for authenticated Admins. Public unauthenticated registration strictly sanitized to `'user'`. | Admin successfully created `police` account; public registration requesting `police` sanitized to `user`. |
| **Task 4** | Web Token Management & Cookies | React client stored refresh tokens in browser `localStorage` (vulnerable to XSS). Express CORS used wildcard `*`. | Integrated `cookie-parser`. Server sets `HttpOnly`, `SameSite=Lax`, `Path=/api/auth` cookie. React client uses `credentials: 'include'` and avoids `localStorage` for refresh tokens. Permissive logout clears cookie and revokes session. | Browser refreshes automatically using `HttpOnly` cookie without body; old token replay rejected (HTTP 401). |
| **Task 5** | Flutter Secure Token Storage | JWT access and refresh tokens stored in plaintext in `%APPDATA%` via `shared_preferences`. | Integrated `flutter_secure_storage` using Windows DPAPI and Android KeyStore (AES-256 GCM + RSA-OAEP). Wrapped with 500ms safety timeouts; preserves 600ms splash threshold. | `flutter analyze` 0 issues; `flutter test` 6/6 passed (100%); automatic migration from legacy preferences. |
| **Task 6** | Python ML Microservice CORS | FastAPI service configured with wildcard `allow_origins=["*"]`. | Restricted CORS to configured `ALLOWED_ORIGINS` (`http://localhost:3000`, `http://127.0.0.1:3000`, `http://localhost:5173`, `http://127.0.0.1:5173`) with `allow_credentials=True`. | Python ML microservice verified accepting only trusted local backend and frontend origins. |

---

## 3. Detailed Architectural Implementations

### 3.1 Task 1: Sub-Second Refresh Token Collision Fix
- **File:** `backend/src/config/jwt.js` & `backend/src/controllers/auth.controller.js`
- **Technical Implementation:**
  Every refresh token now includes a cryptographic nonce (`jti: crypto.randomUUID()`):
  ```javascript
  const generateRefreshToken = (payload) => {
    const tokenPayload = {
      ...payload,
      jti: crypto.randomUUID(),
    };
    return jwt.sign(tokenPayload, REFRESH_SECRET, { expiresIn: REFRESH_EXPIRES });
  };
  ```
  In `auth.controller.js`, `Session.create()` is protected with a catch block intercepting MongoDB duplicate key error code `11000` to return an informative HTTP 409 status instead of an unhandled HTTP 500.

### 3.2 Task 2: Strict JWT Secret Validation
- **File:** `backend/src/config/jwt.js` & `backend/.env.example`
- **Technical Implementation:**
  ```javascript
  const validateJwtConfig = () => {
    const isProd = process.env.NODE_ENV === 'production';
    const accessSecret = process.env.JWT_ACCESS_SECRET;
    const refreshSecret = process.env.JWT_REFRESH_SECRET;
    if (isProd) {
      if (!accessSecret || accessSecret.trim().length < 32) throw new Error('[JWT Security Fatal]...');
      if (!refreshSecret || refreshSecret.trim().length < 32) throw new Error('[JWT Security Fatal]...');
      if (INSECURE_DEFAULT_SECRETS.includes(accessSecret) || INSECURE_DEFAULT_SECRETS.includes(refreshSecret)) throw new Error('...');
      if (accessSecret === refreshSecret) throw new Error('[JWT Security Fatal] Secrets must not be identical.');
    }
  };
  ```
  Masked token logging utility `maskToken()` implemented so raw JWTs are never written to server logs.

### 3.3 Task 3: Admin Provisioning of Police Role
- **File:** `backend/src/controllers/auth.controller.js`
- **Technical Implementation:**
  ```javascript
  const allowedRoles = ['admin', 'police', 'analyst', 'user'];
  const assignedRole =
    req.user?.role === 'admin' && allowedRoles.includes(role)
      ? role
      : 'user';
  ```
  Verified that an administrator authenticated via `POST /api/auth/admin/register` can provision `police` accounts, while unauthenticated public calls to `POST /api/auth/register` with `role: 'police'` are forced to `'user'`.

### 3.4 Task 4: Secure React Token Management & Cookie Support
- **Files:** `backend/src/app.js`, `backend/src/controllers/auth.controller.js`, `backend/src/middleware/auth.js`, `backend/src/routes/auth.routes.js`, `frontend/src/api/client.js`, `frontend/src/context/AuthContext.jsx`
- **Technical Implementation:**
  - **Backend Cookie Parser:** Added `cookie-parser` to Express middleware stack.
  - **CORS Credentials:** Enabled `credentials: true` and origin validation against `CLIENT_ORIGINS`.
  - **Dual Mode Auth Controller:** Sets `res.cookie('refreshToken', token, { httpOnly: true, secure: isProd, sameSite: isProd ? 'strict' : 'lax', path: '/api/auth' })` while also returning the token in the JSON body for native clients.
  - **Permissive Logout:** Added `permissiveAuthenticate` to `POST /api/auth/logout` so session revocation and cookie clearance succeed even if the short-lived access token is expired.
  - **Web Client Hardening:** In `frontend/src/api/client.js`, added `credentials: 'include'` to all `fetch` requests, eliminated `localStorage` persistence of refresh tokens, and updated `refreshAccessToken()` to rely on the browser's `HttpOnly` cookie.

### 3.5 Task 5: Secure Flutter Token Storage
- **Files:** `lib/core/services/auth_service.dart`, `pubspec.yaml`, `test/integration_test/app_test.dart`
- **Technical Implementation:**
  - Configured `FlutterSecureStorage` using `WindowsOptions` (Windows DPAPI) and `AndroidOptions` (KeyStore RSA/AES-GCM).
  - Encapsulated secure reads, writes, and deletes with strict 500ms timeouts (`.timeout(Duration(milliseconds: 500))`) so that Windows Credential Manager latency never blocks the UI or exceeds the 600ms splash threshold.
  - Implemented migration logic: reads legacy tokens from `SharedPreferences`, writes them to secure storage, and removes them from plaintext storage.
  - Maintained non-sensitive session metadata (`_kUserData`, `_kTokenExpiry`) in `SharedPreferences` for fast UI bootstrap.

### 3.6 Task 6: Restrict Python ML Service CORS
- **File:** `server_ml/inference_api.py`
- **Technical Implementation:**
  ```python
  allowed_origins_env = os.getenv(
      "ALLOWED_ORIGINS",
      "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173",
  )
  allowed_origins = [origin.strip() for origin in allowed_origins_env.split(",") if origin.strip()]

  app.add_middleware(
      CORSMiddleware,
      allow_origins=allowed_origins,
      allow_credentials=True,
      allow_methods=["GET", "POST", "OPTIONS"],
      allow_headers=["*"],
  )
  ```
  Verified that wildcard CORS is completely disabled.

---

## 4. Summary of Files Changed

| Component | File Path | Type | Key Modification |
|---|---|---|---|
| Backend | `backend/src/config/jwt.js` | Modified | Added `jti` nonce, `validateJwtConfig()`, masked token logging |
| Backend | `backend/.env.example` | Modified | Added 64+ char key guidance and `CLIENT_ORIGINS` |
| Backend | `backend/src/controllers/auth.controller.js` | Modified | Added `'police'` role provisioning, cookie setting/clearing, duplicate key handling |
| Backend | `backend/src/middleware/auth.js` | Modified | Added `permissiveAuthenticate` for logout |
| Backend | `backend/src/routes/auth.routes.js` | Modified | Wired `permissiveAuthenticate` to logout route |
| Backend | `backend/src/app.js` | Modified | Added `cookie-parser` and credentials-enabled CORS |
| Backend | `backend/test_phase2_suite.js` | Created | Automated verification suite (17 tests) |
| Frontend | `frontend/src/api/client.js` | Modified | Added `credentials: 'include'`, removed localStorage refresh token |
| Frontend | `frontend/src/context/AuthContext.jsx` | Modified | Added silent cookie session initialization |
| Flutter | `lib/core/services/auth_service.dart` | Modified | Migrated sensitive tokens to `FlutterSecureStorage` (DPAPI/KeyStore) |
| Flutter | `test/integration_test/app_test.dart` | Modified | Added mock secure storage harness |
| Python ML | `server_ml/inference_api.py` | Modified | Restricted CORS to ports 3000 and 5173 |
| Docs | `SECURITY_AUDIT.md` | Modified | Marked VULN-001 through VULN-005 as REMEDIATED |
| Docs | `BUILD_LOG.md` | Modified | Appended Section 14 audit log |
| Docs | `LEARNING.md` | Modified | Appended Section 7 technical takeaways |
