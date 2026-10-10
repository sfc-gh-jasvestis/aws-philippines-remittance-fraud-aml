-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-transfer alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_TRANSFERS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic investigation knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.INVESTIGATION_DOCS AS
WITH rules AS (
  SELECT DISTINCT r.DETECTION_RULE, a.CATEGORY
  FROM RAW.OUTLET_DAILY r JOIN RAW.OUTLETS a ON a.ID = r.ENTITY_ID
  WHERE r.CONFIRMED_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, DETECTION_RULE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  DETECTION_RULE,
  CATEGORY || ' - ' || DETECTION_RULE || ' alert investigation' AS TITLE,
  'Synthetic demo SOP of a fictional remittance company; internal policy, not regulatory text. Outlet type: ' || CATEGORY || '. Detection rule: ' || DETECTION_RULE || '. '
  || 'Step 1: open a case, link the alert and hold further payouts above the outlet limit pending review. '
  || 'Step 2: ' || CASE
       WHEN DETECTION_RULE = 'Structuring' THEN 'list transfers sent or paid out at the outlet just below the company''s internal review threshold over 30 days, and check whether they share a sender, beneficiary or phone number and aggregate above it.'
       WHEN DETECTION_RULE = 'Rapid pass-through' THEN 'compare payout times with receipt times, and flag beneficiaries who collect and resend most of the funds within the same day.'
       WHEN DETECTION_RULE = 'Money mule pattern' THEN 'group transfers by beneficiary and count distinct unrelated senders over 14 days; review beneficiaries with many senders and no stated relationship.'
       WHEN DETECTION_RULE = 'Third-party cash-out' THEN 'check whether payouts were collected by someone other than the named beneficiary, and review the ID and authorisation captured at the counter.'
       WHEN DETECTION_RULE = 'Watchlist name match' THEN 'compare the matched name, date of birth and nationality against the screening list entry, and escalate to the sanctions officer before releasing the payout.'
       WHEN DETECTION_RULE = 'High-risk corridor' THEN 'review the sending corridor against the company''s internal corridor risk list, and confirm the stated purpose and source of funds.'
       ELSE 'review the alerted activity against the outlet''s profile and escalate if unexplained.'
     END
  || ' Step 3: if split transfers exceed 5% of the outlet''s transfers or same-hour payouts exceed 40% after review, keep the case open and schedule an outlet compliance visit. '
  || 'Step 4: record the disposition; if suspicion is confirmed, draft a suspicious transaction report (STR) for the compliance officer to approve.' AS CONTENT
FROM rules;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.INVESTIGATION_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, DETECTION_RULE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, DETECTION_RULE, CONTENT FROM SEARCH.INVESTIGATION_DOCS);

-- ---------- Split-transfer share anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.SPLIT_TXN_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, SPLIT_TXN_PCT::FLOAT AS SPLIT_TXN
FROM RAW.OUTLET_DAILY;
CREATE OR REPLACE VIEW ML.SPLIT_TXN_TRAIN AS
SELECT * FROM ML.SPLIT_TXN_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.SPLIT_TXN_SERIES);
CREATE OR REPLACE VIEW ML.SPLIT_TXN_DETECT AS
SELECT * FROM ML.SPLIT_TXN_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.SPLIT_TXN_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.SPLIT_TXN_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.SPLIT_TXN_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'SPLIT_TXN',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.SPLIT_TXN_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS SPLIT_TXN, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.SPLIT_TXN_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.SPLIT_TXN_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'SPLIT_TXN'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.AML_ANALYTICS
  TABLES (
    outlets AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per remittance agent outlet, 90-day totals',
    risk AS ML.SUSPICION_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day suspicious-activity probability per outlet',
    rules AS CURATED.RULE_SUMMARY PRIMARY KEY (DETECTION_RULE)
      COMMENT = 'Alerts, confirmed alerts and STRs by detection rule, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_outlet AS risk (ENTITY_ID) REFERENCES outlets)
  FACTS (
    outlets.alerts_f AS ALERT_COUNT,
    outlets.confirmed_f AS CONFIRMED_COUNT,
    outlets.strs_f AS STR_COUNT,
    outlets.transfers_f AS TRANSFER_COUNT,
    outlets.volume_f AS VOLUME_PHP,
    outlets.review_due_f AS REVIEW_DUE,
    outlets.review_done_f AS REVIEW_COMPLETED,
    risk.suspicion_prob_f AS SUSPICION_PROB_7D,
    rules.rule_alerts_f AS ALERT_COUNT,
    rules.rule_confirmed_f AS CONFIRMED_COUNT,
    rules.rule_strs_f AS STR_COUNT,
    rules.rule_volume_f AS FLAGGED_VOLUME_PHP,
    daily.day_alerts_f AS ALERT_COUNT,
    daily.day_confirmed_f AS CONFIRMED_COUNT,
    daily.day_volume_f AS VOLUME_PHP
  )
  DIMENSIONS (
    outlets.outlet_id AS ENTITY_ID WITH SYNONYMS = ('outlet', 'agent outlet', 'agent location'),
    outlets.outlet_name AS ENTITY_NAME,
    outlets.city AS REGION WITH SYNONYMS = ('city', 'region', 'location') COMMENT = 'Philippine city where the outlet operates',
    outlets.outlet_type AS CATEGORY WITH SYNONYMS = ('outlet type', 'channel', 'agent type'),
    outlets.dd_tier AS DD_TIER COMMENT = 'Agent due-diligence tier 1 (standard) to 3 (enhanced)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    rules.detection_rule AS DETECTION_RULE WITH SYNONYMS = ('rule', 'typology', 'scenario'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    outlets.num_outlets AS COUNT(outlets.outlet_id)
      WITH SYNONYMS = ('entities', 'number of outlets', 'outlet count', 'how many outlets'),
    outlets.alert_precision_pct AS 100 * SUM(outlets.confirmed_f) / NULLIF(SUM(outlets.alerts_f), 0)
      COMMENT = 'Confirmed suspicious alerts / alerts raised',
    outlets.alerts_raised AS SUM(outlets.alerts_f) WITH SYNONYMS = ('alerts', 'alert volume'),
    outlets.confirmed_suspicious AS SUM(outlets.confirmed_f) WITH SYNONYMS = ('true positives', 'confirmed alerts'),
    outlets.strs_filed AS SUM(outlets.strs_f) WITH SYNONYMS = ('STRs', 'suspicious transaction reports'),
    outlets.transfers AS SUM(outlets.transfers_f),
    outlets.total_volume_php AS SUM(outlets.volume_f) WITH SYNONYMS = ('volume', 'remittance volume', 'value sent'),
    outlets.review_compliance_pct AS 100 * SUM(outlets.review_done_f) / NULLIF(SUM(outlets.review_due_f), 0)
      COMMENT = 'Periodic outlet compliance reviews completed / reviews due',
    risk.avg_suspicion_prob AS AVG(risk.suspicion_prob_f),
    rules.rule_alerts AS SUM(rules.rule_alerts_f),
    rules.rule_confirmed AS SUM(rules.rule_confirmed_f),
    rules.rule_strs AS SUM(rules.rule_strs_f),
    rules.rule_precision_pct AS 100 * SUM(rules.rule_confirmed_f) / NULLIF(SUM(rules.rule_alerts_f), 0),
    daily.daily_alerts AS SUM(daily.day_alerts_f),
    daily.daily_confirmed AS SUM(daily.day_confirmed_f),
    daily.daily_volume_php AS SUM(daily.day_volume_f)
  )
  COMMENT = 'Synthetic remittance agent-network AML analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.AML_AGENT
  COMMENT = 'AML assistant over the synthetic agent network of a fictional Philippine remittance company'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give outlet IDs and numbers with units; amounts are in Philippine pesos (PHP)."
  orchestration: "Use aml_analyst for alerts, confirmed suspicious activity, STRs, alert precision, outlets, cities, outlet types, detection rules and risk. Use sop_search for investigation procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: aml_analyst
      description: "Alerts, confirmed suspicious alerts, STRs, alert precision, volume, review compliance, detection rules and suspicious-activity risk scores"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic alert-investigation SOPs by outlet type and detection rule"
tool_resources:
  aml_analyst:
    semantic_view: __DEMO_DB__.APP.AML_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.INVESTIGATION_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-transfer alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), OUTLET_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, VOLUME_PHP FLOAT, SPLIT_TXN_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION PH_REMITTANCE_FRAUD_AML_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (OUTLET_ID, EVENT_TS, VOLUME_PHP, SPLIT_TXN_PCT, SOP_HINT)
    SELECT t.OUTLET_ID, t.EVENT_TS, t.VOLUME_PHP, t.SPLIT_TXN_PCT,
           'Check ' || a.CATEGORY || ' investigation SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_TRANSFERS t
    JOIN RAW.OUTLETS a ON a.ID = t.OUTLET_ID
    LEFT JOIN ML.SUSPICION_RISK_SCORES r ON r.ENTITY_ID = t.OUTLET_ID
    WHERE t.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.OUTLET_ID = t.OUTLET_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('PH_REMITTANCE_FRAUD_AML_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Remittance AML alert',
      'New live-transfer alerts logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_TRANSFER_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_TRANSFERS t
    WHERE t.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.OUTLET_ID = t.OUTLET_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.RULE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.SUSPICION_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.SUSPICION_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.SUSPICION_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'DD_TIER', DD_TIER, 'OUTLET_AGE_YEARS', OUTLET_AGE_YEARS,
             'SPLIT_TXN_PCT', SPLIT_TXN_PCT, 'FAST_PAYOUT_PCT', FAST_PAYOUT_PCT,
             'SPLIT_TXN_7D', SPLIT_TXN_7D, 'CONFIRMED_30D', CONFIRMED_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:SUSPICIOUS::FLOAT, 4) AS SUSPICION_PROB_7D,
         CASE WHEN PRED:probability:SUSPICIOUS::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:SUSPICIOUS::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
