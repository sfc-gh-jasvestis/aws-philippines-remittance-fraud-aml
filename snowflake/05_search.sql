-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Fraud Detection & AML Compliance
-- ============================================================================
USE DATABASE FRAUD_AML;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.BSP_AML_SEARCH
  ON CIRCULAR_TEXT
  ATTRIBUTES CIRCULAR_NUMBER, EFFECTIVE_DATE, TOPIC
  WAREHOUSE = AML_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.BSP_CIRCULARS
);
