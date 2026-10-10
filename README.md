# Philippine Remittance AML - Agent Outlet Monitoring and Suspicious Transfers

Anti-money-laundering monitoring for **40 agent outlets of a fictional Philippine remittance company across 5 cities** (Manila, Cebu City, Davao City, Baguio, Zamboanga City) using Snowflake, optionally with AWS: from a live transfer alert to a 7-day suspicious-activity risk score, an alert email and an AI action memo for the compliance team. The detection rules, investigation SOPs and thresholds are synthetic internal policies of the fictional company; they are not regulatory text.

## Architecture

An AML monitoring pipeline built on **Snowflake** (Dynamic Tables, Snowflake ML, Cortex Search, Cortex Agent, Cortex AI_COMPLETE, SPCS) and, in the full build, **AWS** (Amazon Data Firehose, S3, Bedrock Claude, QuickSight + Amazon Q). Remittance transfer events land in `RAW.LIVE_TRANSFERS`. Dynamic tables curate 90 days of outlet-day history: alerts raised, confirmed suspicious alerts, suspicious transaction reports (STRs) drafted, alert precision and outlet review compliance. Snowflake ML scores 7-day suspicious-activity risk per outlet, forecasts network-wide alert volume and flags split-transfer share anomalies. A Cortex Agent answers questions with SOP citations, and an LLM drafts the compliance action memo.

Interactive diagrams (hover for object names): [Snowflake only](docs/architecture-snowflake.html) | [AWS + Snowflake](docs/architecture-aws.html). The app shows both on its Architecture & Data tab, the current build first. Regenerate them with `python3 docs/build_architecture.py`.

```mermaid
flowchart LR
    subgraph AWS
      SIM[publish_transfers.py] --> FH[Amazon Data Firehose<br/>stream ph-remittance-fraud-aml-transfers]
      FH -->|batched JSON| S3[(Amazon S3<br/>transfers/ landing)]
      BR[Amazon Bedrock<br/>Claude Sonnet 4.5]
      QS[Amazon QuickSight<br/>dashboard + Q topic]
    end
    subgraph Snowflake
      S3 -->|SQS event| PIPE[Snowpipe AUTO_INGEST] --> LIVE[RAW.LIVE_TRANSFERS]
      GEN[02_raw_tables.sql<br/>seeded generator] --> RAW[RAW.OUTLETS / OUTLET_DAILY / AGENT_DOCUMENTS]
      RAW --> DT[CURATED dynamic tables]
      RAW --> ML[Snowflake ML<br/>CLASSIFICATION risk, FORECAST,<br/>ANOMALY_DETECTION]
      DT --> SV[Semantic view<br/>APP.AML_ANALYTICS]
      RAW --> CS[Cortex Search<br/>investigation SOPs]
      SV --> AG[Cortex Agent<br/>APP.AML_AGENT]
      CS --> AG
      LIVE --> AL[Alert APP.LIVE_TRANSFER_ALERT<br/>+ email]
      UDF[APP.BEDROCK_GENERATE<br/>external access UDF]
      TK[Task graph: refresh, then rescore]
      APP[Next.js app on SPCS]
    end
    BR <--> UDF
    DT --> APP
    ML --> APP
    LIVE --> APP
    AG --> APP
    UDF --> APP
    DT --> QS
    ML --> QS
    LIVE --> QS
```

The Snowflake-only build drops the AWS subgraph: `APP.SIMULATE_TRANSFERS` writes to `RAW.LIVE_TRANSFERS`, and the app calls Cortex `AI_COMPLETE` instead of the Bedrock UDF.

## Snowflake Capabilities

| Capability | Implementation |
|-----------|---------------|
| Dynamic Tables | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `RULE_SUMMARY`, `TREND_ANALYSIS` from the RAW tables |
| Snowflake ML | CLASSIFICATION 7-day suspicious-activity risk (`ML.SUSPICION_RISK_SCORES`), 14-day alert-volume FORECAST, split-transfer share ANOMALY_DETECTION |
| Cortex Search | 14 synthetic alert-investigation SOPs (one per outlet type and detection rule) in `SEARCH.INVESTIGATION_SOP_SEARCH` |
| Semantic View | `APP.AML_ANALYTICS` over outlets, detection rules, daily totals and risk |
| Cortex Agent | `APP.AML_AGENT`: Cortex Analyst over the semantic view plus Cortex Search for SOP citations |
| Cortex AI | `AI_COMPLETE('claude-sonnet-4-5')` for grounded answers, and for the action memo in the Snowflake-only build |
| Alerts + Tasks | `APP.LIVE_TRANSFER_ALERT` logs ALERT events and sends email; task graph `TASK_REFRESH_CURATED`, then `TASK_RESCORE_RISK` |
| Snowpark Container Services | Next.js app `APP.PH_REMITTANCE_FRAUD_AML_APP` with 6 tabs: Executive Cockpit, Predictive, Outlet Review, Live Transfers, Ask AI, Architecture & Data |
| Snowpipe | `RAW.LIVE_TRANSFERS_PIPE` AUTO_INGEST from S3 (AWS build only) |

## AWS Services

Used only in the AWS + Snowflake build.

| Service | Role in Demo |
|---------|-------------|
| Amazon Data Firehose | Direct PUT stream `ph-remittance-fraud-aml-transfers` receives simulated remittance transfer events and writes batches to S3 |
| Amazon S3 | Landing bucket (`transfers/`). An event notification goes to the Snowpipe SQS queue |
| Amazon Bedrock | Claude Sonnet 4.5 writes the action memo, called from Snowflake through an external-access UDF |
| Amazon QuickSight | DIRECT_QUERY executive dashboard over Snowflake (daily alerts, confirmed alerts by outlet, suspicious-activity risk) |
| Amazon Q | Natural-language questions over the QuickSight topic `ph-remittance-fraud-aml-topic` |
| AWS IAM | Least-privilege roles for S3, Firehose and Bedrock |

## Personas

These personas are fictional.

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Teresa Villanueva** | Chief Compliance Officer | "What is our alert precision?" "Which detection rules produce the most confirmed suspicious activity?" |
| **Paolo Mendoza** | AML Investigations Lead | "Which outlets are high risk this week, and which SOP applies?" |

## Data

All data is synthetic and seeded, so every rebuild reproduces it. The remittance company, outlets and names are fictional; the data holds outlet-level aggregates only, with no sender or beneficiary records.

| Table | Rows | Description |
|-------|------|-------------|
| RAW.OUTLETS | 40 | Agent outlets across 5 cities and 5 outlet types (Pawnshop Partner, Mall Kiosk, Bank Partner Branch, Convenience Store, Rural Agent), with due-diligence tier |
| RAW.OUTLET_DAILY | 3,600 | Daily outlet observations over 90 days: transfers, volume (PHP), alerts, confirmed alerts, STRs, detection rule, outlet review, split-transfer and same-hour payout shares |
| RAW.AGENT_DOCUMENTS | 40 | Required, on-file and pending agent due-diligence documents per outlet |
| SEARCH.INVESTIGATION_DOCS | 14 | Synthetic alert-investigation SOPs indexed for Cortex Search |
| RAW.LIVE_TRANSFERS | Grows during the demo | Live transfer events from Firehose (AWS build) or `APP.SIMULATE_TRANSFERS` (Snowflake-only build) |
| ML.SUSPICION_RISK_SCORES | 40 | 7-day suspicious-activity probability and risk band per outlet |

## Build Instructions

### Prerequisites
- Snowflake account with ACCOUNTADMIN access, and Cortex AI enabled (AI_COMPLETE, Search, Agent).
- An X-Small warehouse with auto-suspend at or below 120 s, and an existing SPCS compute pool.
- Python 3.11+, `snowflake-connector-python`, Node.js 22+, Docker and the `snow` CLI.
- App image: run `snow spcs image-registry login`, then build and push `ph-remittance-fraud-aml-app:v1` to the database's `APP.IMAGES` repository (see the header of `snowflake/07_deploy_app.sql`).
- AWS build only: `boto3`, AWS credentials for the target account (us-west-2) with Bedrock access, and QuickSight Enterprise.

### SPCS App
```
<DATABASE>.APP.PH_REMITTANCE_FRAUD_AML_APP
```

### Tests
```bash
python -m pytest aws snowflake quicksight
```

For a local run, put `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_AUTHENTICATOR=PROGRAMMATIC_ACCESS_TOKEN`, `SNOWFLAKE_TOKEN` and `DEMO_PLATFORM` in the environment, then run `npm --prefix app run build && npm --prefix app start`.

## Build Modes

Both modes share the same core. They differ in three places, and the app's `DEMO_PLATFORM` setting (in its SPCS spec) switches the memo provider and the Live Transfers tab.

| Layer | Snowflake Only | Full AWS + Snowflake |
|---|---|---|
| Live transfers | `CALL APP.SIMULATE_TRANSFERS(n)` inserts simulated transfer events into `RAW.LIVE_TRANSFERS`. This simulates a transfer feed; it is not Snowpipe Streaming | `aws/publish_transfers.py` to Amazon Data Firehose, then S3, SQS and Snowpipe AUTO_INGEST |
| Action memo | Cortex `AI_COMPLETE('claude-sonnet-4-5')` | Amazon Bedrock Claude Sonnet 4.5 through `APP.BEDROCK_GENERATE` |
| BI and natural-language questions | The SPCS app is the dashboard; questions go to the Cortex Agent | Also a QuickSight dashboard and an Amazon Q topic |
| App setting | `DEMO_PLATFORM: snowflake` | `DEMO_PLATFORM: aws` |

### Snowflake Only

```bash
# 1. Core data and dynamic tables (guarded: new isolated database only)
python snowflake/run_core.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_SNOWFLAKE --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --apply
# 2. Native transfer feed, ML, search, semantic view, agent, alert and task graph
python snowflake/run_intelligence.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_SNOWFLAKE --platform snowflake --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com
# 3. App on SPCS with DEMO_PLATFORM=snowflake (push the image first)
python snowflake/run_intelligence.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_SNOWFLAKE --platform snowflake --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com --files 07_deploy_app.sql --compute-pool <COMPUTE_POOL>
```

During the demo:
- Run `CALL APP.SIMULATE_TRANSFERS(20)` to add live transfer events. For a continuous feed, run `ALTER TASK APP.TASK_SIMULATE_TRANSFERS RESUME`, and `SUSPEND` it afterwards.
- Run `EXECUTE ALERT APP.LIVE_TRANSFER_ALERT` to raise the alert email.
- Run `EXECUTE TASK APP.TASK_REFRESH_CURATED` to refresh the curated tables and rescore risk.

Afterwards, drop the database or run `ALTER SERVICE APP.PH_REMITTANCE_FRAUD_AML_APP SUSPEND`.

### Full AWS + Snowflake

```bash
# 1. Core data and dynamic tables (guarded: new isolated database only)
python snowflake/run_core.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_AWS --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --apply
# 2. AWS ingestion and Bedrock (dry run first, then --apply)
python aws/setup_aws.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_AWS --account <AWS_ACCOUNT_ID> --connection <CONNECTION> --apply
# 3. ML, search, semantic view, agent, alert and task graph
python snowflake/run_intelligence.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_AWS --platform aws --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com
# 4. App on SPCS with DEMO_PLATFORM=aws (push the image first)
python snowflake/run_intelligence.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_AWS --platform aws --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com --files 07_deploy_app.sql --compute-pool <COMPUTE_POOL>
# 5. QuickSight dashboard and Q topic (needs an existing Snowflake data source)
python quicksight/build_dashboards.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_AWS --account <AWS_ACCOUNT_ID> --principal-arn <QUICKSIGHT_USER_ARN> --data-source-arn <DATA_SOURCE_ARN> --prefix ph-remittance-fraud-aml --apply --update --with-topic
```

QuickSight objects must be shared with the QuickSight user who signs in (`--principal-arn`); otherwise the console shows nothing.

During the demo:
- Run `python aws/publish_transfers.py --count 20` to send live transfer events. Firehose buffers for up to 60 seconds before writing to S3.
- Run `EXECUTE ALERT APP.LIVE_TRANSFER_ALERT` to raise the alert email.
- Run `EXECUTE TASK APP.TASK_REFRESH_CURATED` to refresh the curated tables and rescore risk.

Afterwards, `python aws/teardown_aws.py --database PHILIPPINES_REMITTANCE_FRAUD_AML_AWS --account <AWS_ACCOUNT_ID> --connection <CONNECTION> --apply` removes the AWS resources and the account-level Bedrock external-access and S3 storage integrations. It leaves the email integration `PH_REMITTANCE_FRAUD_AML_EMAIL_INT`, which the Snowflake-only build also uses.

## Business Impact

Industry research and Snowflake customer outcomes:
- **98% of financial institutions** reported an increase in financial crime compliance costs -- [LexisNexis Risk Solutions and Forrester Consulting, True Cost of Financial Crime Compliance Global Study, 2023](https://risk.lexisnexis.com/insights-resources/research/true-cost-of-financial-crime-compliance-study-global-report)
- **Western Union** (Snowflake customer), which lets customers send money and pick up cash at more than 550,000 agent locations worldwide, "Reduces Costs 50% And Achieves Multi-Cloud Strategy With Snowflake" -- [Snowflake customer story: Western Union](https://www.snowflake.com/en/customers/all-customers/case-study/western-union/)
- **FIS** (Snowflake customer) rebuilt its capital markets Compliance Suite, which covers branch surveillance, communications surveillance, anti-money laundering and regulatory reporting, on Snowflake: 2.5x faster execution using less than 20% of the compute power, compliance data processed up to 20 times faster, and severity 1 and 2 incidents down 68% -- [Snowflake customer story: FIS](https://www.snowflake.com/en/customers/all-customers/case-study/fis/)

## Key Demo Numbers

These figures are synthetic and come from the seeded demo data. Forecast and anomaly figures can shift slightly with the build day.

- **40 agent outlets**, 3,600 outlet-days over 90 days, across 5 cities and 5 outlet types; PHP 15,626 M in transfer volume monitored
- **659 alerts** raised and **249 confirmed** as suspicious, so alert precision is 37.8%; **103 STRs** drafted
- **Structuring** produces the most confirmed alerts (72 of 249); the 16 holiday volume surge alerts are never confirmed
- **Suspicious-activity model** out-of-time holdout: precision 0.45, recall 0.38 at a 0.5 threshold, against a 0.25 base rate. Five outlets are high risk; the top outlet is OUT-0033, at 77.9%
- **14-day alert forecast** with prediction intervals; **32 of 640** outlet-days flagged as split-transfer share anomalies
- **Outlet review compliance 78.7%**, agent document coverage 59.6%, with 22 documents pending
- **14 SOPs** indexed for Cortex Search and cited by ID in agent answers

## License

Apache 2.0 — See [LICENSE](LICENSE) for details.

This is a personal demo project and is not an official Snowflake offering. It comes with no support or warranty. Industry metrics cited are from publicly available third-party research and Snowflake customer stories; they represent reported outcomes and are not guarantees of results.
