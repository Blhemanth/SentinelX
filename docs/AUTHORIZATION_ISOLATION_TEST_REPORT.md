# SentinelX — User Authorization & Data Isolation Test Report

**Milestone:** Urgent Presentation Readiness — P0 Security & Authorization  
**Execution Timestamp:** 2026-11-23T20:58:00+05:30  
**Environment:** Windows 11, Node.js v20, MongoDB v7 (port 27017), Express 4.19  
**Auditor / Engineer:** Principal Application Security Architect & Senior Flutter Desktop Engineer  

---

## 1. Executive Summary

During the pre-presentation audit of SentinelX, multi-user login data leakage and missing tenant authorization controls were identified as a critical vulnerability. Previously, incident query endpoints (`GET /api/logs`) and single-incident inspection (`GET /api/logs/:id`) lacked tenant filtering and ownership validation, allowing users of the civilian role (`user`) to view organizational surveillance data and incidents reported by other users. Furthermore, client-supplied `userId` or `createdBy` attributes could be forged during incident creation (`POST /api/logs`).

In P0, a comprehensive ownership model and strict Role-Based Access Control (RBAC) was engineered and deployed:
1. **Schema Upgrade:** Added indexed `createdBy` reference (`mongoose.Schema.Types.ObjectId`, ref `User`) to `CrimeLog` with compound indexing `{ createdBy: 1, frameTimestamp: -1 }`.
2. **Server-Side Ownership Binding:** All client-supplied ownership keys (`createdBy`, `userId`) are stripped unconditionally. Ownership is bound exclusively to the verified cryptographic JWT identity (`req.user.userId`).
3. **Tenant Query Scoping:** Regular civilian users (`role: 'user'`) are strictly scoped to `filter.createdBy = req.user.userId`. They cannot view records created by other tenants or unowned surveillance logs.
4. **IDOR Prevention:** Direct access via `GET /api/logs/:id` verifies ownership. Civilian users attempting to read records belonging to other tenants receive an immediate `403 Forbidden`.
5. **RBAC Action Controls:** Tactical operations (`dispatchStatus` updates, alert acknowledgments, and deletions) are strictly restricted to authorized staff (`analyst`, `police`, `admin`). Standard users attempting to tamper with these endpoints receive `403 Forbidden`.
6. **Legacy Safety Isolation:** Historical surveillance records without an explicit owner (`createdBy: null`) remain accessible to control room staff (`admin`, `analyst`) for audit purposes, but are strictly hidden from civilian users.
7. **Client-Side State Purge & Generation Guard:** On Flutter logout and account switching, all Riverpod state (`detectionsAccumulatorProvider`, `alertsProvider`, `threatTimelineProvider`, `incidentDispatchProvider`, and `selectedCameraProvider`) is completely wiped. An incrementing `sessionGeneration` counter rejects in-flight asynchronous responses from prior sessions.

---

## 2. Authorization & RBAC Matrix

| Role | Read All Logs | Read Own Logs | Create Log | Update Dispatch | Acknowledge | Delete Log | View Tenant Stats | View Global Stats |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **user** (Civilian) | ❌ | ✅ | ✅ (Bound to self) | ❌ (403) | ❌ (403) | ❌ (403) | ✅ (Strictly self) | ❌ |
| **police** (Officer) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (403) | ✅ | ✅ |
| **analyst** (Control) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (403) | ✅ | ✅ |
| **admin** (Superuser) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (Admin only) | ✅ | ✅ |

---

## 3. Automated Test Execution Results

**Test Runner:** `node backend/test_user_isolation.js`  
**Total Scenarios:** 19  
**Passed:** 19 (100.0%)  
**Failed:** 0  

```text
================================================================
   SentinelX — User Data Isolation & IDOR Verification Suite    
================================================================

[PASS] #1: UserId Spoofing Prevention on Incident Creation - Declared UserB ID was ignored; bound to verified token owner: 6b045b72c7a9ae8fc517cd7d
[PASS] #2: User A Second Incident Creation
[PASS] #3: User B Incident Creation and Verified Ownership
[PASS] #4: Listing Data Isolation for User A - User A sees only their own incidents (count: 2), User B logs excluded
[PASS] #5: Listing Data Isolation for User B - User B sees only their own incidents (count: 1), User A logs excluded
[PASS] #6: IDOR Direct Access Blocked (GET /api/logs/:id across tenants) - Expected HTTP 403 Forbidden, got HTTP 403
[PASS] #7: Legitimate Owner Direct Access (GET /api/logs/:id) - Owner User A successfully fetched incident: HTTP 200
[PASS] #8: Unauthenticated Access Blocked (HTTP 401 on GET endpoints) - List: 401, Single: 401
[PASS] #9: Standard User Forbidden from Updating Dispatch Status (RBAC Enforcement) - Expected HTTP 403 Forbidden, got HTTP 403
[PASS] #10: Standard User Forbidden from Acknowledging Incident (RBAC Enforcement) - Expected HTTP 403 Forbidden, got HTTP 403
[PASS] #11: Standard User Forbidden from Deleting Incident (Admin Only RBAC) - Expected HTTP 403 Forbidden, got HTTP 403
[PASS] #12: Analyst Global Surveillance Visibility (Staff Access) - Analyst sees incidents across all users (total visible: 20)
[PASS] #13: Analyst Direct Incident Inspection (Staff Permission) - HTTP 200
[PASS] #14: Analyst Query Filter by Tenant User (?createdBy=) - Filtered correctly to User A only (2 logs)
[PASS] #15: Legacy Unowned Records Safety (Hidden from Civilian Users) - User list excluded legacy: true, Direct fetch: HTTP 403 (Forbidden)
[PASS] #16: Legacy Unowned Records Visible to Staff for Audit Oversight - Analyst retained access to historical unowned record: true
[PASS] #17: Aggregated Statistics Tenant Isolation (GET /api/logs/stats) - User A total: 2 (strictly their 2 logs), Global total: 33
[PASS] #18: Malformed and Non-Existent ObjectId Defensive Handling - Malformed ID returned HTTP 404, Non-existent returned HTTP 404
[PASS] #19: Admin Authorized Deletion (RBAC Verification) - HTTP 200

================================================================
                 ISOLATION AUDIT SUMMARY                        
================================================================
Passed: 19/19 (100.0%)

ALL ISOLATION & IDOR TESTS PASSED PERFECTLY.
```

---

## 4. Regression Verification

In addition to user isolation tests, the existing Phase 4.2.6 cryptographic HMAC and protocol verification suite was executed:
- **Suite:** `node backend/test_phase4_2_6_verification.js`
- **Result:** **25/25 tests PASSED (100.0%)**
- Confirmed that HMAC token binding, Protocol v2 enforcement, anti-replay sliding nonce cache, RIFF WAV parser validation, and Python ML PCM audio preprocessing remain 100% operational and undamaged.

---

## 5. Artifacts and Source Links

- Test Suite: [test_user_isolation.js](file:///b:/SentinelX/backend/test_user_isolation.js)
- Schema Definition: [CrimeLog.js](file:///b:/SentinelX/backend/src/models/CrimeLog.js)
- Logs Controller: [logs.controller.js](file:///b:/SentinelX/backend/src/controllers/logs.controller.js)
- Routes & RBAC Middleware: [logs.routes.js](file:///b:/SentinelX/backend/src/routes/logs.routes.js)
- Flutter Auth Service: [auth_service.dart](file:///b:/SentinelX/lib/core/services/auth_service.dart)
- Flutter Provider Reset: [providers.dart](file:///b:/SentinelX/lib/core/providers/providers.dart)
- Flutter Shell Session Listener: [app_shell.dart](file:///b:/SentinelX/lib/shell/app_shell.dart)
