-- Synthetic outlet-day observations for the agent network of a fictional
-- Philippine remittance company. Nothing is seeded as a prediction. Randomness
-- is HASH-seeded, so every rebuild is reproducible: per-outlet suspicion
-- propensity, compliance drift between periodic outlet reviews, missed reviews,
-- outlet-type-weighted detection rules, false-positive alerts, and two
-- network-wide holiday volume surges.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.OUTLETS AS
WITH outlets AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS OUTLET_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT OUTLET_INDEX,
         MOD(ABS(HASH(OUTLET_INDEX, 'phrfa_age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(OUTLET_INDEX, 'phrfa_rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(OUTLET_INDEX, 'phrfa_review')), 1000000) / 1e6 AS U_REVIEW,
         MOD(ABS(HASH(OUTLET_INDEX, 'phrfa_discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(OUTLET_INDEX, 'phrfa_tier')), 1000000) / 1e6 AS U_TIER
  FROM outlets
)
SELECT 'OUT-' || LPAD(OUTLET_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic outlet ' || LPAD(OUTLET_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every city and outlet
       -- type is present.
       CASE MOD(OUTLET_INDEX, 5) WHEN 0 THEN 'Manila' WHEN 1 THEN 'Cebu City'
            WHEN 2 THEN 'Davao City' WHEN 3 THEN 'Baguio' ELSE 'Zamboanga City' END AS REGION,
       CASE MOD(OUTLET_INDEX, 8) WHEN 0 THEN 'Pawnshop Partner' WHEN 1 THEN 'Pawnshop Partner'
            WHEN 2 THEN 'Pawnshop Partner' WHEN 3 THEN 'Mall Kiosk' WHEN 4 THEN 'Mall Kiosk'
            WHEN 5 THEN 'Bank Partner Branch' WHEN 6 THEN 'Convenience Store'
            ELSE 'Rural Agent' END AS CATEGORY,
       OUTLET_INDEX,
       1 + FLOOR(U_TIER * 3) AS DD_TIER,
       ROUND(0.3 + U_AGE * 7.7, 1) AS OUTLET_AGE_YEARS,
       -- Base daily probability of suspicious activity 0.5%-3.3%; ~13% of outlets
       -- are repeat hot spots (x3).
       (0.005 + U_RATE * 0.028) * IFF(U_RATE > 0.87, 3, 1) AS BASE_SUSPICION_RATE,
       7 * (1 + FLOOR(U_REVIEW * 3)) AS REVIEW_INTERVAL_DAYS,
       0.5 + U_DISCIPLINE * 0.48 AS REVIEW_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.OUTLET_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), surge_events AS (
  -- Two holiday volume surges; every outlet in the city is alerted.
  SELECT * FROM VALUES (33, 'Cebu City'), (71, 'Manila') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT a.ID AS ENTITY_ID, a.OUTLET_INDEX, a.CATEGORY, a.REGION, a.OUTLET_AGE_YEARS,
         a.BASE_SUSPICION_RATE, a.REVIEW_INTERVAL_DAYS, a.REVIEW_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + a.OUTLET_INDEX * 3, a.REVIEW_INTERVAL_DAYS) AS DAYS_SINCE_REVIEW,
         MOD(ABS(HASH(a.ID, d.DAY_INDEX, 'phrfa_sus')), 1000000) / 1e6 AS U_SUS,
         MOD(ABS(HASH(a.ID, d.DAY_INDEX, 'phrfa_detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(a.ID, d.DAY_INDEX, 'phrfa_fp')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(a.ID, d.DAY_INDEX, 'phrfa_rule')), 1000000) / 1e6 AS U_RULE,
         MOD(ABS(HASH(a.ID, d.DAY_INDEX, 'phrfa_done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(a.ID, d.DAY_INDEX, 'phrfa_transfers')), 1000000) / 1e6 AS U_TRANSFERS,
         MOD(ABS(HASH(a.ID, d.DAY_INDEX, 'phrfa_noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(a.ID, d.DAY_INDEX, 'phrfa_str')), 1000000) / 1e6 AS U_STR,
         m.REGION IS NOT NULL AS SURGE_EVENT
  FROM RAW.OUTLETS a CROSS JOIN days d
  LEFT JOIN surge_events m ON m.DAY_INDEX = d.DAY_INDEX AND m.REGION = a.REGION
), review AS (
  SELECT *,
         IFF(DAYS_SINCE_REVIEW = 0, 1, 0) AS REVIEW_DUE,
         IFF(DAYS_SINCE_REVIEW = 0 AND U_DONE < REVIEW_COMPLETION_PROB, 1, 0) AS REVIEW_COMPLETED,
         -- Compliance drift rises between periodic outlet reviews; weak review
         -- discipline carries it over.
         DAYS_SINCE_REVIEW / REVIEW_INTERVAL_DAYS + (1 - REVIEW_COMPLETION_PROB) AS DRIFT
  FROM base
), activity AS (
  SELECT *,
         CASE WHEN U_SUS < LEAST(0.5, BASE_SUSPICION_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + OUTLET_AGE_YEARS))) / 4 THEN 2
              WHEN U_SUS < LEAST(0.5, BASE_SUSPICION_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + OUTLET_AGE_YEARS))) THEN 1
              ELSE 0 END AS SUSPICIOUS_COUNT
  FROM review
), alerts AS (
  SELECT *,
         -- Rules catch about 82% of suspicious activity; the rest goes undetected.
         IFF(SURGE_EVENT, 0, IFF(U_DETECT < 0.82, SUSPICIOUS_COUNT, 0)) AS CONFIRMED_COUNT,
         -- False positives: higher for high-volume outlet types.
         IFF(SURGE_EVENT, 1, IFF(U_FP < CASE CATEGORY WHEN 'Bank Partner Branch' THEN 0.18
                                                      WHEN 'Convenience Store' THEN 0.13
                                                      WHEN 'Rural Agent' THEN 0.11 ELSE 0.07 END, 1, 0)) AS FALSE_POSITIVE_COUNT
  FROM activity
), measured AS (
  SELECT *,
         CONFIRMED_COUNT + FALSE_POSITIVE_COUNT AS ALERT_COUNT,
         ROUND(CASE CATEGORY WHEN 'Bank Partner Branch' THEN 640 WHEN 'Convenience Store' THEN 210
                             WHEN 'Rural Agent' THEN 55 WHEN 'Mall Kiosk' THEN 280 ELSE 390 END
               * (0.7 + 0.6 * U_TRANSFERS) * (1 + 0.6 * SUSPICIOUS_COUNT)) AS TRANSFER_COUNT,
         CASE CATEGORY WHEN 'Bank Partner Branch' THEN 26000 WHEN 'Convenience Store' THEN 4600
                       WHEN 'Rural Agent' THEN 6800 WHEN 'Mall Kiosk' THEN 7900 ELSE 9300 END
           * (0.8 + 0.4 * U_NOISE) AS AVG_TICKET_PHP
  FROM alerts
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       TRANSFER_COUNT,
       ROUND(TRANSFER_COUNT * AVG_TICKET_PHP, 2) AS VOLUME_PHP,
       ALERT_COUNT, CONFIRMED_COUNT,
       IFF(CONFIRMED_COUNT > 0 AND U_STR < 0.55, 1, 0) AS STR_FILED,
       CASE WHEN ALERT_COUNT = 0 THEN 'None'
            WHEN SURGE_EVENT THEN 'Holiday volume surge'
            WHEN CATEGORY = 'Pawnshop Partner' THEN IFF(U_RULE < 0.5, 'Structuring', IFF(U_RULE < 0.8, 'Money mule pattern', 'Third-party cash-out'))
            WHEN CATEGORY = 'Mall Kiosk' THEN IFF(U_RULE < 0.45, 'Structuring', IFF(U_RULE < 0.8, 'Rapid pass-through', 'Watchlist name match'))
            WHEN CATEGORY = 'Bank Partner Branch' THEN IFF(U_RULE < 0.55, 'Rapid pass-through', 'High-risk corridor')
            WHEN CATEGORY = 'Convenience Store' THEN IFF(U_RULE < 0.45, 'Structuring', IFF(U_RULE < 0.8, 'Rapid pass-through', 'Watchlist name match'))
            ELSE IFF(U_RULE < 0.5, 'Money mule pattern', IFF(U_RULE < 0.75, 'Third-party cash-out', 'High-risk corridor')) END AS DETECTION_RULE,
       REVIEW_DUE, REVIEW_COMPLETED,
       ROUND(0.6 + 2.2 * DRIFT + 3.4 * SUSPICIOUS_COUNT + U_NOISE * 0.9, 2) AS SPLIT_TXN_PCT,
       ROUND(15 + 11 * DRIFT + 13 * SUSPICIOUS_COUNT + U_NOISE * 7, 1) AS FAST_PAYOUT_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Agent due-diligence document coverage per outlet (snapshot).
CREATE TABLE RAW.AGENT_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Pawnshop Partner' THEN 'Agency agreement' WHEN 'Mall Kiosk' THEN 'Lease and permit'
                     WHEN 'Bank Partner Branch' THEN 'Partner bank attestation'
                     WHEN 'Convenience Store' THEN 'Franchise agreement' ELSE 'Agent owner ID and permit' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'phrfa_req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'phrfa_file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'phrfa_file')), 5) < 1 + MOD(ABS(HASH(ID, 'phrfa_req')), 4),
           MOD(ABS(HASH(ID, 'phrfa_pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.OUTLETS;
