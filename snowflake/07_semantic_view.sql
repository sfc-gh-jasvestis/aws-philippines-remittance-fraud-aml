-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Fraud Detection & AML Compliance
-- ============================================================================
USE DATABASE FRAUD_AML;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.AML_COMPLIANCE_ANALYTICS
  COMMENT = 'Fraud detection, AML compliance, sanctions screening, and STR analytics'
AS
  TABLES (
    CURATED.ACCOUNT_RISK_SCORE AS account_risk_score,CURATED.STRUCTURING_DETECTION AS structuring_detection,CURATED.NETWORK_ANALYSIS AS network_analysis,CURATED.AML_TIMESERIES AS aml_timeseries
  );
