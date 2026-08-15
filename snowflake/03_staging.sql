-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Fraud Detection & AML Compliance
-- Country: PHILIPPINES | Currency: PHP
-- ============================================================================
USE DATABASE FRAUD_AML;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- KYC_DOCUMENTS: 320,000 rows — Scanned IDs and documents processed via Textract
-- TRANSACTIONS: 5,600,000 rows — 60 days of remittance transactions from Kinesis
-- ACCOUNTS: 780,000 rows — Customer accounts with risk tier and KYC status
-- ALERTS_HISTORY: 45,000 rows — Historical AML alerts with dispositions
-- SANCTIONS_LIST: 28,000 rows — Consolidated sanctions watchlists (OFAC, UN, EU, BSP)
-- STR_FILINGS: 1,200 rows — Suspicious Transaction Reports filed with AMLC
-- BSP_CIRCULARS: 95 rows — BSP regulatory circulars on AML/CFT requirements
