# SentinelX Web Console — Design System & Visual Specification

**Document ID:** `DOC-FRONTEND-DESIGN-SYSTEM-001`  
**Application:** SentinelX Web Console (MERN Stack)  
**Theme:** Cybersecurity Operations Center (SOC) // High-Tech Tactical Defense  
**Date:** 2026-11-24  
**Authoritative Classification:** Visual Design Specification & Token Registry  

---

## 1. Visual Philosophy & Identity

The SentinelX Web Console is modeled after Tier-1 Cybersecurity Operations Centers (SOCs) and Automated Tactical Dispatch Platforms. The design prioritizes:
- **Maximum High-Contrast Legibility:** Crisp typography on dark navy/charcoal backgrounds minimizes operator eye strain during 24/7 monitoring.
- **Strict Visual Hierarchy:** Immediate separation between critical threat alarms, ongoing police responses, training simulations, and normal sensor streams.
- **Zero Browser Default Aesthetics:** All buttons, dropdowns, tables, and inputs adhere to a unified high-tech glassmorphism and elevated panel design.
- **Responsive Adaptability:** Fluid, non-overlapping layouts scaling smoothly from mobile handhelds (390px) to ultra-wide operations walls (1920px+).

---

## 2. Design Tokens & Color Palette

### 2.1 Core Palette
| Token Name | Hex Code | Purpose & Semantic Role |
| :--- | :--- | :--- |
| `--bg-main` | `#0A0E1D` | Canvas / primary viewport background |
| `--bg-sidebar` | `#10172A` | Navigation sidebar background |
| `--bg-card` | `#151F35` | Standard card and analytical panel background |
| `--bg-elevated`| `#1B2942` | Highlighted cards, modal dialogues, input fields |
| `--accent-cyan`| `#00D9D9` | Primary tactical accent, active routes, brand highlights |
| `--accent-blue`| `#477BFF` | Police dispatch, tactical responses, secondary accent |
| `--accent-purple`|`#8B5CF6`| ML inference telemetry and neural worker markers |
| `--status-success`|`#21C997`| Normal state, healthy sensors, verified secure |
| `--status-warning`|`#F5B942`| Low/Medium anomalies, pending review, drill simulations |
| `--status-critical`|`#FF5268`| Critical threat alerts, active acoustic distress |
| `--text-primary`| `#F4F7FF` | Headings, primary metrics, active labels |
| `--text-secondary`|`#9AA9C4`| Descriptive copy, table metadata, timestamps |
| `--text-muted` | `#64748B` | Subtle captions, deactivated controls |

### 2.2 Elevation, Glows & Borders
- **Glass Border Standard:** `rgba(0, 217, 217, 0.20)`
- **Subtle Glass Border:** `rgba(255, 255, 255, 0.08)`
- **Cyan Glow:** `0 0 20px rgba(0, 217, 217, 0.20)`
- **Critical Alert Glow:** `0 0 25px rgba(255, 82, 104, 0.35)`
- **Card Shadow:** `0 8px 32px 0 rgba(0, 0, 0, 0.45)`
- **Elevated Shadow:** `0 10px 36px 0 rgba(0, 0, 0, 0.55)`

---

## 3. Typography Hierarchy

| Category | Font Family | Weights | Usage |
| :--- | :--- | :--- | :--- |
| **Display / Brand** | `Exo 2` | 700, 800, 900 | Brand wordmark, screen titles, hero metrics |
| **Primary Sans** | `Inter` | 400, 500, 600, 700 | Body copy, forms, table content, tooltips |
| **Telemetry Mono** | `JetBrains Mono` | 500, 600, 700 | Timestamps, ObjectIds, dBFS levels, badges |

---

## 4. Standardized Component Classes

### 4.1 Buttons
- **`.btn-primary`:** Gradient from `#00D9D9` to `#477BFF`, dark text `#050811`, font-weight 700, cyan glow shadow.
- **`.btn-critical`:** Gradient from `#FF5268` to `#D8263E`, white text, red glow shadow.
- **`.btn-secondary`:** Elevated `#1B2942` background, 1px border, cyan hover outline.
- **`.btn-police`:** Gradient from `#477BFF` to `#2557D6`, white text, tactical dispatch badge.
- **`.btn-ghost`:** Transparent background, subtle border, hover highlight.

### 4.2 Badges & Status Indicators
- **`.badge-critical`:** Red tint with 45% border for active threats and distress events.
- **`.badge-warning` / `.badge-high`:** Amber tint for medium threats and unacknowledged alerts.
- **`.badge-success` / `.badge-resolved`:** Emerald tint for resolved incidents and normal status.
- **`.badge-police` / `.badge-en-route`:** Blue tint for CAD-assigned tactical units.
- **`.badge-cyan`:** Cyan tint for system telemetry and authenticated sessions.
- **`.badge-simulation`:** Amber tint with dashed border for operator drill simulations.

### 4.3 Pulsing Status Indicators (`.pulse-dot`)
- **`.pulse-critical`:** 8px red dot with 1.8s expanding pulse animation.
- **`.pulse-live`:** 8px green dot with expanding pulse for live camera/microphone streams.
- **`.pulse-police`:** 8px blue dot for active law enforcement responses.

### 4.4 Form Controls & Inputs
- Inputs, selects, and textareas use `#0E1526` dark background, `#F4F7FF` text, 1px subtle border, and a 2px `#00D9D9` glow on focus.

### 4.5 Data Tables (`.sentinel-table`)
- Sticky headers with `#10172A` background, monospace uppercase column titles, subtle horizontal dividers, and row hover highlights.

### 4.6 Skeleton Shimmer Loaders (`.skeleton`)
- Animated gradient shimmer for asynchronous loading states, eliminating abrupt layout shifts.

---

## 5. Responsive Breakpoint Specification

| Breakpoint | Width (px) | Layout Adjustments |
| :--- | :--- | :--- |
| **Mobile** | `< 768px` | Collapsible slide-over sidebar, single-column dashboard cards, stacked navigation |
| **Tablet Portrait** | `768px - 1023px` | Compact sidebar icon mode, 2-column metric grid |
| **Tablet Landscape**| `1024px - 1365px`| Expanded sidebar, 4-column overview metrics, 2-column analytics |
| **Desktop** | `1366px - 1439px`| Full command layout, live telemetry tickers, multi-feed camera grid |
| **Full Operations** | `≥ 1440px` | Max-width 7xl/8xl centered composition, full forensic panels |
