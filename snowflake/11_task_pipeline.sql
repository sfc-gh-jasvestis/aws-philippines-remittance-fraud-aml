-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Fraud Detection & AML Compliance
-- ============================================================================
USE DATABASE FRAUD_AML;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_PARSE_KYC
  WAREHOUSE = AML_WH
  SCHEDULE = 'USING CRON 0 */4 * * * UTC'
  COMMENT = 'Parse new KYC documents with AI_PARSE_DOCUMENT'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_SCORE_ACCOUNTS
  WAREHOUSE = AML_WH
  AFTER APP.TASK_PARSE_KYC
  COMMENT = 'Refresh account risk scores'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_GENERATE_STR
  WAREHOUSE = AML_WH
  AFTER APP.TASK_SCORE_ACCOUNTS
  COMMENT = 'Auto-generate STR narratives for confirmed suspicious accounts'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_GENERATE_STR RESUME;
ALTER TASK APP.TASK_SCORE_ACCOUNTS RESUME;
ALTER TASK APP.TASK_PARSE_KYC RESUME;
