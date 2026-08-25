-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Fraud Detection & AML Compliance
-- ============================================================================
USE DATABASE FRAUD_AML;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_philippines_remittance_fraud_aml_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: STRUCTURING_ALERT
CREATE OR REPLACE ALERT APP.STRUCTURING_ALERT
  WAREHOUSE = AML_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Potential transaction structuring detected'
IF (EXISTS (
  SELECT 1 FROM CURATED.ACCOUNT_RISK_SCORE
  WHERE 1=1 -- Condition: STRUCTURING_PROBABILITY > 0.8 for any account
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_remittance_fraud_aml_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Fraud Detection & AML Compliance: Potential transaction structuring detected',
    'Potential transaction structuring detected'
  );

ALTER ALERT APP.STRUCTURING_ALERT RESUME;

-- Alert: SANCTIONS_HIT_ALERT
CREATE OR REPLACE ALERT APP.SANCTIONS_HIT_ALERT
  WAREHOUSE = AML_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'High-confidence sanctions list match'
IF (EXISTS (
  SELECT 1 FROM CURATED.ACCOUNT_RISK_SCORE
  WHERE 1=1 -- Condition: SANCTIONS_MATCH_SCORE > 0.95
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_remittance_fraud_aml_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Fraud Detection & AML Compliance: High-confidence sanctions list match',
    'High-confidence sanctions list match'
  );

ALTER ALERT APP.SANCTIONS_HIT_ALERT RESUME;

