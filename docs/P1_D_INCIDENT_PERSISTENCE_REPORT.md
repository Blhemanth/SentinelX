# SentinelX — Milestone P1-D: Incident Persistence & Identity Reconciliation Report

**Document ID:** `DOC-P1-D-INCIDENT-PERSISTENCE-001`  
**Milestone:** P1-D (Help Detection, SOS Workflow & Incident Dispatch Restoration)  
**System Architecture:** MongoDB 6.0+ / Mongoose ODM / Flutter StateNotifier / Node.js Express  
**Authoritative Classification:** Database Identity & Persistence Architecture  

---

## 1. Objective & Architectural Policy

In surveillance and emergency dispatch systems, data integrity and incident traceability are paramount. Every emergency event, operator alert, and dispatch action must be anchored by an immutable, unique database identifier.

Prior to Milestone P1-D, client-generated synthetic identifiers (`INC-xxxxxxx`) caused Mongoose `CastError` failures and prevented reliable multi-screen synchronization. This report documents the authoritative persistence lifecycle and identity reconciliation model implemented in Milestone P1-D.

---

## 2. Authoritative Database Identity Model

### 2.1 Backend-Authoritative MongoDB ObjectId
* **Policy:** Client applications NEVER invent authoritative incident identifiers.
* **Mechanism:**
  1. When an operator initiates a distress drill (`TRIGGER DISTRESS DRILL`) or manual distress alert, the client calls `CrimeLogService.createCrimeLog(...)`.
  2. The Node.js Express backend validates tenant session credentials, sanitizes the payload, assigns `createdBy: req.user.userId`, and commits the document to MongoDB.
  3. MongoDB generates an immutable 12-byte / 24-character hexadecimal ObjectId (e.g., `6740ad880000000000000001`).
  4. The backend returns the committed record with `_id`.
  5. The Flutter `IncidentDispatchNotifier` extracts `realId = created['_id'].toString()` and constructs the `DistressIncident` instance bound to that genuine database key.

### 2.2 Reconciled Dispatch State Progression
Status updates strictly reference the 24-hex ObjectId:
```text
[Flutter Client]                                                 [MongoDB Backend]
   │                                                                     │
   ├─── POST /api/logs (isSimulation: true) ────────────────────────────>│
   │<── HTTP 201 Created {_id: "6740ad88..."} ──────────────────────────┤
   │                                                                     │
   ├─── PATCH /api/logs/6740ad88.../dispatch (assigned_police) ─────────>│
   │<── HTTP 200 OK {status: "assigned_police"} ────────────────────────┤
   │                                                                     │
   ├─── PATCH /api/logs/6740ad88.../dispatch (en_route) ───────────────>│
   │<── HTTP 200 OK {status: "en_route"} ───────────────────────────────┤
   │                                                                     │
   ├─── PATCH /api/logs/6740ad88.../dispatch (on_scene) ───────────────>│
   │<── HTTP 200 OK {status: "on_scene"} ───────────────────────────────┤
   │                                                                     │
   └─── PATCH /api/logs/6740ad88.../dispatch (resolved) ───────────────>│
    <── HTTP 200 OK {status: "resolved"} ───────────────────────────────┘
```

---

## 3. Defensive Legacy Migration & Self-Healing

To guarantee backward compatibility with legacy offline test scenarios or in-memory fixtures:
1. `assignToPolice(incidentId)` inspects `RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(incidentId)`.
2. If the incident ID is non-hexadecimal (e.g. legacy `INC-DEMO-001`), the repository automatically posts the incident metadata to `createCrimeLog`, captures the newly minted MongoDB `_id`, replaces the in-memory record in `state`, and proceeds with the dispatch update using the genuine ObjectId.
3. This completely prevents `CastError` exceptions from reaching the backend log stream.

---

## 4. Multi-Screen State Synchronization

### 4.1 Bidirectional Status Mapping Parity
| Flutter `DispatchStatus` Enum | MongoDB Backend String | Web Dashboard State | Visual Indicator |
| :--- | :--- | :--- | :--- |
| `pendingReview` | `unassigned` | `Pending Review` | Amber / Pulsing Dot |
| `assignedToPolice` | `assigned_police` | `Assigned to Police` | Blue Badge |
| `enRoute` | `en_route` | `Unit En Route` | Cyan Badge |
| `onScene` | `on_scene` | `Unit On Scene` | Purple Badge |
| `resolved` | `resolved` | `Resolved` | Green Badge (Omitted from active queue) |

### 4.2 Deduplication Protection
In `backend/src/controllers/logs.controller.js`:
* The backend enforces a 3-second deduplication window for incident creation matching the same `cameraId`, `threatClass`, and `createdBy` user.
* Duplicate rapid clicks on the drill button return the existing record (HTTP 200) rather than spawning phantom duplicate database entries.

---

## 5. Verification Test Summary

The persistence and identity reconciliation architecture was verified via automated integration tests:
* **Test 1:** `triggerDistress creates incident and resolves genuine MongoDB ObjectId` &rarr; **PASS**
* **Test 2:** `assignToPolice with synthetic INC-DEMO-001 provisions backend record and avoids CastError` &rarr; **PASS**
* **Test 3:** `updatePoliceStatus transitions status safely with valid backend ID` &rarr; **PASS**
* **Test 4:** `Full tactical status progression across all 4 stages` &rarr; **PASS**
* **Test 5:** `syncFromBackend retains authenticated drill simulations` &rarr; **PASS**
