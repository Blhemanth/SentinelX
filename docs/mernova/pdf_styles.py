# SentinelX - MERNOVA PDF Shared Styling & Conversion Library

SHARED_CSS = """
@page {
  size: A4 portrait;
  margin: 18mm 16mm 18mm 16mm;
  @top-left {
    content: "SENTINELX // MERNOVA COMPETITION DOCUMENTATION";
    font-family: 'Segoe UI', Arial, sans-serif;
    font-size: 8pt;
    font-weight: 600;
    color: #64748b;
    border-bottom: 1px solid #e2e8f0;
    padding-bottom: 4px;
  }
  @top-right {
    content: "PHASE 4.3.5.1 VERIFIED";
    font-family: 'Segoe UI', Arial, sans-serif;
    font-size: 8pt;
    font-weight: 700;
    color: #0284c7;
    border-bottom: 1px solid #e2e8f0;
    padding-bottom: 4px;
  }
  @bottom-left {
    content: "CONFIDENTIAL & PROPRIETARY — FOR MERNOVA EVALUATION ONLY";
    font-family: 'Segoe UI', Arial, sans-serif;
    font-size: 7.5pt;
    color: #94a3b8;
  }
  @bottom-right {
    content: "Page " counter(page);
    font-family: 'Segoe UI', Arial, sans-serif;
    font-size: 8pt;
    font-weight: 600;
    color: #64748b;
  }
}

* {
  box-sizing: border-box;
}

body {
  font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, 'Inter', Roboto, sans-serif;
  color: #1e293b;
  background: #ffffff;
  font-size: 10pt;
  line-height: 1.55;
  margin: 0;
  padding: 0;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

/* Headings */
h1, h2, h3, h4, h5 {
  color: #0f172a;
  font-weight: 700;
  margin-top: 1.4em;
  margin-bottom: 0.5em;
  line-height: 1.25;
}

h1 {
  font-size: 20pt;
  color: #032b43;
  border-bottom: 2px solid #0284c7;
  padding-bottom: 6px;
  margin-top: 0;
}

h2 {
  font-size: 14pt;
  color: #0f172a;
  border-bottom: 1px solid #cbd5e1;
  padding-bottom: 4px;
  page-break-after: avoid;
}

h3 {
  font-size: 11.5pt;
  color: #0369a1;
  margin-top: 1.2em;
  page-break-after: avoid;
}

h4 {
  font-size: 10pt;
  color: #334155;
  margin-top: 1em;
  page-break-after: avoid;
}

p {
  margin: 0.6em 0;
  text-align: justify;
}

/* Document Cover / Header Banner */
.doc-header {
  background: linear-gradient(135deg, #0a192f 0%, #0f3254 100%);
  color: #ffffff;
  padding: 20px 24px;
  border-radius: 8px;
  margin-bottom: 24px;
  border-left: 6px solid #00f2fe;
}

.doc-header h1 {
  color: #ffffff;
  border-bottom: none;
  font-size: 22pt;
  margin: 0 0 4px 0;
  padding: 0;
  letter-spacing: -0.5px;
}

.doc-header .subtitle {
  font-size: 11pt;
  color: #38bdf8;
  font-weight: 500;
  margin-bottom: 12px;
}

.doc-header .meta-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
  background: rgba(255, 255, 255, 0.08);
  padding: 10px 14px;
  border-radius: 6px;
  font-size: 8.5pt;
}

.doc-header .meta-item strong {
  display: block;
  color: #94a3b8;
  text-transform: uppercase;
  font-size: 7pt;
  letter-spacing: 0.5px;
}

.doc-header .meta-item span {
  color: #ffffff;
  font-weight: 600;
}

/* Badges */
.badge {
  display: inline-block;
  padding: 2px 7px;
  border-radius: 4px;
  font-size: 7.5pt;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin: 0 2px;
}

.badge-verified {
  background: #dcfce7;
  color: #166534;
  border: 1px solid #86efac;
}

.badge-conditional {
  background: #fef3c7;
  color: #92400e;
  border: 1px solid #fcd34d;
}

.badge-unvalidated {
  background: #ffedd5;
  color: #9a3412;
  border: 1px solid #fdba74;
}

.badge-planned {
  background: #e0f2fe;
  color: #0369a1;
  border: 1px solid #7dd3fc;
}

.badge-untested {
  background: #f1f5f9;
  color: #475569;
  border: 1px solid #cbd5e1;
}

.badge-danger {
  background: #fee2e2;
  color: #991b1b;
  border: 1px solid #fca5a5;
}

/* Dual-Perspective Explanation Cards */
.dual-container {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin: 14px 0;
  page-break-inside: avoid;
}

.perspective-card {
  padding: 12px 14px;
  border-radius: 6px;
  font-size: 9pt;
  line-height: 1.5;
}

.card-beginner {
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  border-left: 4px solid #16a34a;
}

.card-beginner h4 {
  color: #15803d;
  margin: 0 0 6px 0;
  font-size: 9.5pt;
  display: flex;
  align-items: center;
}

.card-technical {
  background: #f0f9ff;
  border: 1px solid #bae6fd;
  border-left: 4px solid #0284c7;
}

.card-technical h4 {
  color: #0369a1;
  margin: 0 0 6px 0;
  font-size: 9.5pt;
  display: flex;
  align-items: center;
}

/* Callout Boxes */
.callout {
  padding: 10px 14px;
  border-radius: 6px;
  margin: 12px 0;
  font-size: 9pt;
  page-break-inside: avoid;
}

.callout-info {
  background: #f8fafc;
  border-left: 4px solid #0284c7;
  border-top: 1px solid #e2e8f0;
  border-right: 1px solid #e2e8f0;
  border-bottom: 1px solid #e2e8f0;
}

.callout-warning {
  background: #fffbeb;
  border-left: 4px solid #d97706;
  border-top: 1px solid #fef3c7;
  border-right: 1px solid #fef3c7;
  border-bottom: 1px solid #fef3c7;
}

.callout-danger {
  background: #fef2f2;
  border-left: 4px solid #dc2626;
  border-top: 1px solid #fee2e2;
  border-right: 1px solid #fee2e2;
  border-bottom: 1px solid #fee2e2;
}

.callout-success {
  background: #f0fdf4;
  border-left: 4px solid #16a34a;
  border-top: 1px solid #dcfce7;
  border-right: 1px solid #dcfce7;
  border-bottom: 1px solid #dcfce7;
}

/* Tables */
table {
  width: 100%;
  border-collapse: collapse;
  margin: 12px 0;
  font-size: 8.5pt;
  page-break-inside: auto;
}

tr {
  page-break-inside: avoid;
  page-break-after: auto;
}

th, td {
  border: 1px solid #cbd5e1;
  padding: 6px 10px;
  text-align: left;
  vertical-align: top;
}

th {
  background: #f1f5f9;
  color: #1e293b;
  font-weight: 700;
  font-size: 8pt;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

tr:nth-child(even) td {
  background: #f8fafc;
}

/* Code & Architecture Diagrams */
pre, code {
  font-family: 'Cascadia Code', 'Consolas', 'Courier New', monospace;
  font-size: 8pt;
}

code {
  background: #f1f5f9;
  color: #0f172a;
  padding: 1px 4px;
  border-radius: 3px;
}

pre {
  background: #0f172a;
  color: #f8fafc;
  padding: 12px 14px;
  border-radius: 6px;
  overflow-x: auto;
  line-height: 1.4;
  margin: 10px 0;
  border: 1px solid #334155;
  page-break-inside: avoid;
}

.diagram-box {
  background: #09101d;
  color: #38bdf8;
  border: 1px solid #1e293b;
  border-left: 4px solid #00f2fe;
  padding: 12px 16px;
  border-radius: 6px;
  font-family: 'Cascadia Code', monospace;
  font-size: 7.5pt;
  line-height: 1.35;
  margin: 12px 0;
  white-space: pre;
  overflow-x: auto;
  page-break-inside: avoid;
}

/* Speaker Script Specific Styling */
.speaker-cue {
  display: flex;
  align-items: center;
  background: #e0f2fe;
  color: #0369a1;
  padding: 4px 10px;
  border-radius: 4px;
  font-weight: 700;
  font-size: 9pt;
  margin: 12px 0 6px 0;
  border-left: 4px solid #0284c7;
}

.cue-time {
  background: #0284c7;
  color: #ffffff;
  padding: 2px 6px;
  border-radius: 3px;
  font-size: 7.5pt;
  margin-right: 8px;
}

.speaking-text {
  background: #ffffff;
  border-left: 3px solid #cbd5e1;
  padding: 6px 14px;
  margin: 4px 0 10px 0;
  font-size: 9.5pt;
  font-style: normal;
  color: #1e293b;
}

.speaking-text strong {
  color: #0f172a;
}

.slide-transition {
  background: #fef3c7;
  color: #92400e;
  padding: 4px 10px;
  border-radius: 4px;
  font-size: 8pt;
  font-weight: 600;
  margin: 8px 0;
  border: 1px dashed #f59e0b;
}

.contingency-box {
  background: #fff1f2;
  border: 1px solid #fecdd3;
  border-left: 4px solid #e11d48;
  padding: 8px 12px;
  border-radius: 6px;
  margin: 10px 0;
  font-size: 8.5pt;
}

.contingency-box strong {
  color: #9f1239;
}

/* Q&A Item */
.qa-item {
  margin: 12px 0;
  padding: 10px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  background: #ffffff;
  page-break-inside: avoid;
}

.qa-question {
  font-weight: 700;
  color: #0f172a;
  font-size: 9.5pt;
  margin-bottom: 4px;
  display: flex;
}

.qa-q-num {
  color: #0284c7;
  font-weight: 800;
  margin-right: 8px;
  min-width: 32px;
}

.qa-answer {
  color: #334155;
  font-size: 9pt;
  line-height: 1.5;
  padding-left: 40px;
}

.qa-defense-tip {
  margin-top: 6px;
  padding: 4px 8px;
  background: #f8fafc;
  border-left: 3px solid #0284c7;
  font-size: 8pt;
  color: #475569;
}

/* Page Control Classes */
.page-break {
  page-break-before: always;
}

.no-break {
  page-break-inside: avoid;
}

.section-toc {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 12px 18px;
  margin: 16px 0;
}

.section-toc ol {
  margin: 0;
  padding-left: 20px;
}

.section-toc li {
  margin: 4px 0;
  font-size: 8.5pt;
  color: #334155;
}
"""

def wrap_html(title, body_content):
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{title}</title>
  <style>
{SHARED_CSS}
  </style>
</head>
<body>
{body_content}
</body>
</html>
"""
