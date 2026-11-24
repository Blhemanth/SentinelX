# SentinelX — Milestone P1-D: Drill Isolation & Emergency Safety Architecture Report

**Document ID:** `DOC-P1-D-DRILL-ISOLATION-001`  
**Milestone:** P1-D (Help Detection, SOS Workflow & Incident Dispatch Restoration)  
**System Architecture:** Node.js Express / MongoDB / Flutter Client / Protocol v2 Safety Architecture  
**Authoritative Classification:** Operational Safety & Emergency Dispatch Isolation  

---

## 1. Executive Summary & Non-Negotiable Constraint

In any automated emergency dispatch system deployed for public safety or critical infrastructure, training drills, operator simulations, and demonstrations must be strictly, mathematically isolated from real law enforcement and emergency dispatch endpoints. Under no circumstances may a test drill result in an actual emergency phone call, live tactical radio alert, or live police unit deployment.

This report documents the defense-in-depth isolation architecture implemented across the SentinelX backend and Flutter client in Milestone P1-D.

---

## 2. Multi-Layer Isolation Architecture

SentinelX enforces emergency isolation across four distinct layers:

```text
┌─────────────────────────────────────────────────────────────┐
│ LAYER 1: UI User Confirmation & Visual Distinction          │
│ • Modal Dialog: Explicit "CONFIRM DISTRESS DRILL"           │
│ • Orange/Amber Visual Banners: "🎯 [DRILL SIMULATION]"       │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ LAYER 2: Transport & Schema Tagging                         │
│ • Payload: isSimulation: true, detectionSource: drill_sim   │
│ • MongoDB Pre-Save Hook: Forces bidirectional sync of flags  │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ LAYER 3: Business Logic Gatekeeper (CrimeLog Model)         │
│ • isEmergencyEligible(log) strictly returns false for drills │
│ • Clamps dispatchStatus to 'unassigned' if created with auth │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ LAYER 4: Backend Dispatch Endpoint Enforcement              │
│ • PATCH /api/logs/:id/dispatch                              │
│ • Real police dispatch returns HTTP 400 Bad Request         │
│ • Only designated simulated units permitted                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Schema & Database Enforcement

### 3.1 Mongoose Schema Isolation (`backend/src/models/CrimeLog.js`)
```javascript
isSimulation: {
  type: Boolean,
  default: false,
  index: true,
},
```

### 3.2 Pre-Save Hook Invariant
The pre-save hook enforces bidirectional consistency:
```javascript
crimeLogSchema.pre('save', function (next) {
  if (this.detectionSource === 'drill_simulation' || this.isSimulation === true) {
    this.isSimulation = true;
    this.detectionSource = 'drill_simulation';
  }
  // Clamp dispatchStatus on simulation creation
  if (this.isSimulation && this.isNew && this.dispatchStatus === 'assigned_police') {
    this.dispatchStatus = 'unassigned';
  }
  next();
});
```

### 3.3 Strict Emergency Ineligibility
```javascript
crimeLogSchema.statics.isEmergencyEligible = function (log) {
  // Simulations and drills are NEVER emergency eligible
  if (log.isSimulation === true || log.detectionSource === 'drill_simulation') {
    return false;
  }
  // Subprocess fallbacks and legacy unclassified are clamped out
  if (log.detectionSource === 'subprocess_fallback' || log.detectionStatus === 'subprocess_fallback') {
    return false;
  }
  ...
};
```

---

## 4. Backend Dispatch Protection (`backend/src/controllers/logs.controller.js`)

In `updateDispatchStatus`:
```javascript
// Strictly forbid assigning drill simulations to real law enforcement units
if (log.isSimulation || log.detectionSource === 'drill_simulation') {
  const isSimulatedUnit = req.body.isSimulatedUnit === true || 
    (assignedTo && /simulat|drill|training/i.test(assignedTo));
  if (!isSimulatedUnit) {
    return res.status(400).json({
      status: 'error',
      message: 'Drill simulations are training exercises and cannot be dispatched to law enforcement.',
      code: 'DRILL_DISPATCH_PROHIBITED'
    });
  }
}
```

If an operator or compromised client attempts to send `assignedTo: "Metro Police Tactical Unit #104"` on a drill simulation, the backend rejects the request with **HTTP 400 Bad Request** (`DRILL_DISPATCH_PROHIBITED`).

---

## 5. Authorized Training Drill Dispatch

Training drills can still be assigned to simulated training units for operator evaluation:
* **Assigned Unit:** `Simulated Police Patrol Unit #104 (Training Drill Response)`
* **Audit Trail:** Recorded in MongoDB with `assignedTo`, `policeNotes`, and status progression (`assigned_police` &rarr; `en_route` &rarr; `on_scene` &rarr; `resolved`).
* **Emergency Dispatchers:** Zero notifications or webhook triggers sent to external police or emergency dispatch interfaces.

---

## 6. Automated Isolation Test Verification

The isolation policy was validated across 17 automated test assertions in `backend/test_phase4_2_3_dispatch_isolation.js`:
* **Test 1:** Critical drill simulation is strictly isolated from emergency dispatch &rarr; **PASS**
* **Test 2:** High-confidence drill simulation is strictly isolated from emergency dispatch &rarr; **PASS**
* **Test 3:** Attempt to dispatch drill simulation to real police returns HTTP 400 Bad Request &rarr; **PASS**
* **Test 4:** Drill simulation created with `assigned_police` is clamped to `unassigned` &rarr; **PASS**
* **Test 5:** Client attempt to spoof `ml_real` sanitized to `manual_entry` &rarr; **PASS**
* **Overall Result:** **17/17 PASSED (100.0%)**
