-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Fraud Detection & AML Compliance
-- ============================================================================
USE DATABASE FRAUD_AML;
USE SCHEMA CURATED;

-- ACCOUNT_RISK_SCORE: Real-time account risk score combining KYC, behavior, and network signals
-- Source: ACCOUNTS, TRANSACTIONS, KYC_DOCUMENTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.ACCOUNT_RISK_SCORE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = AML_WH
AS
SELECT * FROM RAW.ACCOUNTS;
-- TODO: Replace with actual join/aggregation logic per demo

-- STRUCTURING_DETECTION: Identifies transactions structured below reporting thresholds
-- Source: TRANSACTIONS, ACCOUNTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.STRUCTURING_DETECTION
  TARGET_LAG = '5 minutes'
  WAREHOUSE = AML_WH
AS
SELECT * FROM RAW.TRANSACTIONS;
-- TODO: Replace with actual join/aggregation logic per demo

-- NETWORK_ANALYSIS: Account relationships and potential mule networks
-- Source: TRANSACTIONS, ACCOUNTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.NETWORK_ANALYSIS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = AML_WH
AS
SELECT * FROM RAW.TRANSACTIONS;
-- TODO: Replace with actual join/aggregation logic per demo

-- AML_TIMESERIES: Daily alert volumes and suspicious patterns for anomaly detection
-- Source: ALERTS_HISTORY, TRANSACTIONS
CREATE OR REPLACE DYNAMIC TABLE CURATED.AML_TIMESERIES
  TARGET_LAG = '5 minutes'
  WAREHOUSE = AML_WH
AS
SELECT * FROM RAW.ALERTS_HISTORY;
-- TODO: Replace with actual join/aggregation logic per demo

