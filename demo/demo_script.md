# Philippine Remittance AML

**Philippines - Remittance agent network**
Use case: Anti-money-laundering monitoring of agent outlets

> AML monitoring for 40 agent outlets of a fictional Philippine remittance company across 5 cities: dynamic tables, a holdout-evaluated suspicious-activity classifier, an alert-volume forecast and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile alerts, confirmed alerts, STRs and outlet review compliance from RAW outlet data, with checks in `run_core.py`
- **Suspicious-activity classification** gives a holdout-evaluated next-7-day probability per outlet
- **Alert forecast** projects 14 days of network-wide alert volume with prediction intervals, for investigator staffing
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live transfers**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.OUTLETS` (40 rows) |
| Fact table | `RAW.OUTLET_DAILY` (3,600 outlet-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `RULE_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.SUSPICION_RISK_SCORES`, `ML.SUSPICION_RISK_HOLDOUT_METRICS`, `ML.ALERT_FORECAST`, `ML.SPLIT_TXN_ANOMALIES` |

Cities: Manila, Cebu City, Davao City, Baguio, Zamboanga City.
Outlet types: Pawnshop Partner, Mall Kiosk, Bank Partner Branch, Convenience Store, Rural Agent.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Alert Precision | 37.8% |
| Alerts Raised | 659 |
| Confirmed Suspicious | 249 |
| STRs Filed | 103 |
| Transfer Volume (PHP M) | 15,626 |
| Outlet Review Compliance | 78.7% |
| Outlets Monitored | 40 |
| Agent Document Coverage | 59.6% |
| Agent Documents Pending | 22 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily alerts against confirmed alerts, alerts and confirmed alerts by detection rule, outlet table
2. Predictive: holdout metrics, risk bands, 14-day alert forecast, split-transfer share anomalies
3. Outlet Review: outlet review compliance, agent document coverage and pending documents, review compliance against confirmed alerts, then generate the action memo
4. Live Transfers: run `CALL APP.SIMULATE_TRANSFERS(20)` (Snowflake only) or `python aws/publish_transfers.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_TRANSFER_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- About three alerts in eight are confirmed as suspicious (37.8%). Most alert reviews end as false positives, which is where investigator time goes.
- Structuring produces the most confirmed alerts. Holiday volume surge alerts hit every outlet in a city at once and are never confirmed.
- The risk model is evaluated on a time-based holdout: precision 0.45 and recall 0.38 at 0.5, against a 0.25 base rate. Present it as triage, not a verdict.
- Holiday volume surges are excluded from model training, because they are city-wide and not outlet-driven.
- The SOPs are synthetic internal procedures of the fictional company; they are not regulatory text.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
