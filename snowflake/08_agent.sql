-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Fraud Detection & AML Compliance
-- ============================================================================
USE DATABASE FRAUD_AML;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.AML_COMPLIANCE_AGENT
  COMMENT = 'Fraud Detection & AML Compliance AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'FRAUD_AML.APP.AML_COMPLIANCE_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'FRAUD_AML.SEARCH.BSP_AML_SEARCH', TOOL_DESCRIPTION => 'Search documents for Remittances & Fintech information')
  )
  SYSTEM_PROMPT = 'You are the AML Compliance Intelligence Agent for a Philippine remittance company processing 5.6M transactions monthly, subject to BSP and AMLC regulations.';
