# Fraud Detection & AML Compliance

**Philippines - Remittances & Fintech**
Use case: Fraud & AML

> Philippine remittance companies process $36B annually under strict BSP/AMLC oversight — Snowflake combines Textract-parsed KYC documents with transaction anomaly detection and ML classification for end-to-end fraud and AML compliance.

## Why Snowflake

Snowflake ingests KYC documents via Textract + AI_PARSE_DOCUMENT, streams transactions from Kinesis, detects suspicious patterns with ML.ANOMALY_DETECTION, classifies risk with ML.CLASSIFICATION, and generates STR reports — full AML pipeline, native SQL

- **Textract + AI_PARSE_DOCUMENT for KYC** - Only demo combining AWS document extraction with Snowflake AI parsing for KYC
- **ML.ANOMALY_DETECTION + ML.CLASSIFICATION for AML** - Dual ML approach — anomaly detection for pattern discovery, classification for scoring
- **Cortex Complete for STR narrative generation** - AI auto-generates regulatory filing narratives — 4 hours to 20 minutes
- **BSP/AMLC regulatory context** - Philippine-specific AML requirements with BSP circular search
- **Network graph analysis for mule rings** - Account-to-account relationship mapping for coordinated fraud detection
- **Kinesis + Snowpipe Streaming for real-time monitoring** - Sub-minute transaction monitoring at 5.6M monthly transaction scale

## What is deployed

| | |
|---|---|
| Database | `PH_REMITTANCE_FRAUD_AML` |
| Service | `PH_REMITTANCE_FRAUD_AML_APP` |
| Compute pool | `SEA_DEMOS_PHILIPPINES_POOL` |
| Dimension table | `RAW.BSP_CIRCULARS` (20 rows) |
| Fact table | `RAW.TRANSACTIONS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | PHP (₱) |

Regions in play: Metro Manila, Cebu, Davao, Pampanga, Iloilo
Segments: Account Takeover, Mule Account, Structuring, Sanctions Hit

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh PH_REMITTANCE_FRAUD_AML
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Alerts Generated | `12,400` | average per event |
| SAR Filed | `847` | total across Bsp Circulars |
| False Positive Rate | `84%` | average per event |
| Blocked Transactions | `₱142M` | total across Bsp Circulars |
| Model Precision | `42%` | average per event |
| Typology Coverage | `94%` | average per event |
| Avg Investigation Time | `4.2 days` | average per event |


## Demo flow

1. Executive Cockpit
2. Fraud Patterns
3. KYC & Documents
4. Ask AI
5. Architecture & Data

## Talking points

- **5.6M** - transactions monitored monthly
- **847 alerts** - active in AML investigation queue
- **23 STRs** - pending AMLC filing
- **47 accounts** - linked in detected mule ring
- **₱23M** - in structured transactions identified
- **320K documents** - parsed by AI_PARSE_DOCUMENT

## Business impact

- AMLC received 2.3M covered and suspicious transaction reports in 2023 (AMLC Philippines)
- Philippine financial institutions spend ₱15-25B annually on AML compliance (BAP Philippines)
- AI-powered AML reduces false positives by 60-80%, saving investigation hours (Deloitte)
- Automated STR generation reduces filing time by 80% while improving quality (McKinsey)

---
Generated from `generator/demo_specs/aws-philippines-remittance-fraud-aml.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-philippines-remittance-fraud-aml` instead.
