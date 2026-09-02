-- Generated from generator/demo_specs/aws-philippines-remittance-fraud-aml.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-philippines-remittance-fraud-aml
-- This is the schema that is actually deployed for PH_REMITTANCE_FRAUD_AML.

-- PH_REMITTANCE_FRAUD_AML  (Fraud Detection & AML Compliance)
-- generated from generator/demo_specs/aws-philippines-remittance-fraud-aml.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS PH_REMITTANCE_FRAUD_AML;
CREATE SCHEMA IF NOT EXISTS PH_REMITTANCE_FRAUD_AML.RAW;
CREATE SCHEMA IF NOT EXISTS PH_REMITTANCE_FRAUD_AML.CURATED;
CREATE SCHEMA IF NOT EXISTS PH_REMITTANCE_FRAUD_AML.APP;
USE DATABASE PH_REMITTANCE_FRAUD_AML;

-- 5 real regions; entity names carry their region so the two always agree
