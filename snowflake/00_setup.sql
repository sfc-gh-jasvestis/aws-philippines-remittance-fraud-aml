-- ============================================================================
-- Fraud Detection & AML Compliance
-- Philippine remittance companies process $36B annually under strict BSP/AMLC oversight — Snowflake combines Textract-parsed KYC documents with transaction anomaly detection and ML classification for end-to-end fraud and AML compliance.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS FRAUD_AML;
CREATE WAREHOUSE IF NOT EXISTS AML_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE FRAUD_AML;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE AML_WH;
