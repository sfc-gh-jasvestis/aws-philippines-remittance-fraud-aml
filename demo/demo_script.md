# Demo Script: Fraud Detection & AML Compliance
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake ingests KYC documents via Textract + AI_PARSE_DOCUMENT, streams transactions from Kinesis, detects suspicious patterns with ML.ANOMALY_DETECTION, classifies risk with ML.CLASSIFICATION, and generates STR reports — full AML pipeline, native SQL"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Atty. Margarita Elena Locsin** | Chief Compliance Officer | React App (SPCS) | AMLC compliance, STR filing deadlines, regulatory exam readiness, sanctions screening |
| **Gabriel Santos Ocampo** | Fraud Investigations Lead | Amazon QuickSight | Fraud patterns, mule account networks, transaction structuring, investigation queue |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 7 tables | KYC_DOCUMENTS (320000), TRANSACTIONS (5600000), ACCOUNTS (780000), ALERTS_HISTORY (45000), SANCTIONS_LIST (28000), STR_FILINGS (1200), BSP_CIRCULARS (95) |
| **CURATED** | 4 Dynamic Tables | ACCOUNT_RISK_SCORE, STRUCTURING_DETECTION, NETWORK_ANALYSIS, AML_TIMESERIES |
| **ML** | ML.ANOMALY_DETECTION + ML.CLASSIFICATION | Forecasting + anomaly detection |
| **AI** | AI_PARSE_DOCUMENT, AI_CLASSIFY, COMPLETE | Classification + extraction |
| **Search** | Cortex Search | 95 documents indexed |
| **Agent** | AML_COMPLIANCE_AGENT | Semantic View + Search tools |


---

## The Story

The Philippines' $36B remittance industry operates under strict BSP and AMLC oversight. A Philippine remittance company must monitor 5.6M monthly transactions across 200+ corridors for money laundering, terrorism financing, and fraud. Manual KYC review takes days. Alert investigation backlogs grow. STR filing deadlines loom. Snowflake automates the entire pipeline — from document parsing to anomaly detection to STR generation.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "5.6 million transactions monitored this month — 780K customer accounts screened."

**Action**: Point at 5.6M transactions monitored

### [0:45–1:30] FRAUD PATTERNS

**Show**: Fraud Patterns tab

> "ML.ANOMALY_DETECTION flagged structuring alerts up 40% this week — new pattern emerging."

**Action**: Show alert volume timeseries with anomaly markers

### [1:30–2:15] KYC & DOCUMENTS

**Show**: KYC & Documents tab

> "AI_PARSE_DOCUMENT processed 320K KYC documents — extracting name, ID number, address."

**Action**: Show parsed document example with extracted fields

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Atty. Locsin asks: 'How many CTRs did we file last quarter?'"

**Action**: Type: 'CTRs filed last quarter?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Kinesis + Textract → Snowpipe + AI_PARSE_DOCUMENT → ML scoring → STR generation — one pipeline."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **Textract + AI_PARSE_DOCUMENT for KYC** — Only demo combining AWS document extraction with Snowflake AI parsing for KYC
2. **ML.ANOMALY_DETECTION + ML.CLASSIFICATION for AML** — Dual ML approach — anomaly detection for pattern discovery, classification for scoring
3. **Cortex Complete for STR narrative generation** — AI auto-generates regulatory filing narratives — 4 hours to 20 minutes
4. **BSP/AMLC regulatory context** — Philippine-specific AML requirements with BSP circular search
5. **Network graph analysis for mule rings** — Account-to-account relationship mapping for coordinated fraud detection
6. **Kinesis + Snowpipe Streaming for real-time monitoring** — Sub-minute transaction monitoring at 5.6M monthly transaction scale


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM FRAUD_AML.RAW.TRANSACTIONS` → 5600000
- [ ] `SELECT COUNT(*) FROM FRAUD_AML.RAW.KYC_DOCUMENTS` → 320000
- [ ] `SELECT COUNT(*) FROM FRAUD_AML.CURATED.STRUCTURING_DETECTION WHERE STRUCTURING_PROBABILITY > 0.8` → >40

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM FRAUD_AML.ML.AML_ANOMALY_RESULTS WHERE IS_ANOMALY = TRUE` → >0
- [ ] `SELECT COUNT(*) FROM FRAUD_AML.ML.FRAUD_CLASSIFICATION_RESULTS WHERE IS_SUSPICIOUS = TRUE` → >=847

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM FRAUD_AML.AI.PARSED_KYC_DOCUMENTS` → 320000

