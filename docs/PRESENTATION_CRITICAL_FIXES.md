# SentinelX — Presentation Critical Fixes Log

**Milestone:** Urgent Presentation Readiness & Critical Bug Fixes  
**Status:** P0 Complete (Dashboard Crash & Backend Authorization / Data Isolation)  
**Date:** 2026-11-23  

---

## 1. Issue 1: Dashboard RenderFlex Crash (COMPLETED)

### Root Cause
At [sentinel_widgets.dart](file:///b:/SentinelX/lib/shared/widgets/sentinel_widgets.dart#L273), `SectionHeader` contained a `Row` with a `Spacer()` widget:
```dart
Row(
  children: [
    Text(title, ...),
    const Spacer(), // Expanded(flex: 1)
    if (trailing != null) trailing!,
  ],
)
```
In Flutter, `Spacer` expands along the main axis. When `SectionHeader` was placed in an unconstrained horizontal layout context (such as an outer `Row` or an unconstrained viewport in [audio_page.dart](file:///b:/SentinelX/lib/features/audio/audio_page.dart)), the incoming maximum width constraint was infinite ($\infty$). A flex factor applied to an unbounded constraint causes `FlutterError: RenderFlex children have non-zero flex but incoming width constraints are unbounded`.

### Fix Implementation
1. Refactored `SectionHeader` in [sentinel_widgets.dart](file:///b:/SentinelX/lib/shared/widgets/sentinel_widgets.dart) using `LayoutBuilder`:
   - When incoming width constraints are bounded (`constraints.hasBoundedWidth`): Uses `mainAxisAlignment: MainAxisAlignment.spaceBetween` with `Flexible(child: Text(title, overflow: TextOverflow.ellipsis))` and trailing widget. No unbounded flex assertions.
   - When incoming width constraints are unbounded (`!constraints.hasBoundedWidth`): Renders `Row(mainAxisSize: MainAxisSize.min)` with zero flex widgets (no `Spacer`, no `Expanded`), shrink-wrapping safely.
2. In [audio_page.dart](file:///b:/SentinelX/lib/features/audio/audio_page.dart), removed the redundant outer `Row(children: [SectionHeader, Spacer(), trailing])` and passed the trailing widget directly into `SectionHeader(trailing: ...)`.
3. Added automated unit tests in [section_header_layout_test.dart](file:///b:/SentinelX/test/unit/section_header_layout_test.dart) verifying bounded containers, unbounded parent `Row` containers, and long-title overflow handling.

### Verification Result
- `flutter test test/unit/section_header_layout_test.dart` -> **3/3 PASS (100%)**.

---

## 2. Issue 2: Multi-User Data Isolation & Backend Authorization (COMPLETED)

### Root Cause
1. In [CrimeLog.js](file:///b:/SentinelX/backend/src/models/CrimeLog.js), the incident schema lacked an explicit `createdBy` user reference.
2. In [logs.controller.js](file:///b:/SentinelX/backend/src/controllers/logs.controller.js), `getLogs` returned all database records to any authenticated user regardless of tenant, and `getLogById` had no ownership checks, allowing any authenticated user to inspect another user's incidents (Insecure Direct Object Reference - IDOR).
3. In `createLog`, client payloads could include arbitrary `createdBy` or `userId` values.
4. On the client side in [auth_service.dart](file:///b:/SentinelX/lib/core/services/auth_service.dart), logout merely deleted local JWT tokens without notifying or purging active Riverpod StateNotifiers (`detectionsAccumulatorProvider`, `alertsProvider`, `threatTimelineProvider`, `incidentDispatchProvider`), allowing the previous session's detections to linger in memory.
5. In-flight asynchronous requests initiated under an old session could complete and repopulate state after a new user logged in.

### Fix Implementation
1. **Model Schema:** Updated `CrimeLog.js` with:
   ```javascript
   createdBy: {
     type: mongoose.Schema.Types.ObjectId,
     ref: 'User',
     default: null,
     index: true,
   }
   ```
   Compound index added: `{ createdBy: 1, frameTimestamp: -1 }`. Legacy unowned records default safely to `null`.
2. **Controller Logic:**
   - `createLog`: Unconditionally strips client-supplied `createdBy` and `userId`. Derives `payload.createdBy = req.user.userId` from verified JWT.
   - `getLogs`: Role `user` is strictly filtered by `filter.createdBy = req.user.userId`. Staff roles (`admin`, `analyst`, `police`) can view all incidents or filter by `?createdBy=`.
   - `getLogById`: Staff roles can inspect any incident. Role `user` is denied with `403 Forbidden` if `log.createdBy != req.user.userId`. Defends against malformed ObjectIds with 404 (not 500 CastError).
   - `getStats`: Regular users receive aggregate counts strictly filtered by their own `createdBy`. Staff receives global counts.
   - `deleteLog`, `acknowledgeLog`, `updateDispatchStatus`: Defends with ObjectId validation and strict RBAC enforcement.
3. **Client-Side Purge & Generation Guard:**
   - In [auth_service.dart](file:///b:/SentinelX/lib/core/services/auth_service.dart), added `_sessionGeneration` counter and callback hooks (`registerSessionResetCallback`, `triggerSessionReset`).
   - In [providers.dart](file:///b:/SentinelX/lib/core/providers/providers.dart), added `resetUserSessionState(dynamic ref)` which purges detections, alerts, threat timeline, dispatch incidents, selected camera, and navigation state.
   - In [app_shell.dart](file:///b:/SentinelX/lib/shell/app_shell.dart), registered session reset listener and attached `resetUserSessionState` to the logout button.
   - In [incident_dispatch_repository.dart](file:///b:/SentinelX/lib/core/services/incident_dispatch_repository.dart), checked `sessionGeneration` before and after asynchronous backend fetches; in-flight responses from an expired session are safely discarded.

### Verification Result
- `node backend/test_user_isolation.js` -> **19/19 PASS (100%)**.
- `node backend/test_phase4_2_6_verification.js` -> **25/25 PASS (100%)**.
