-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.OUTLET_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.OUTLET_DAILY observation
    LEFT JOIN RAW.OUTLETS outlet ON outlet.ID = observation.ENTITY_ID
    WHERE outlet.ID IS NULL OR observation.TRANSFER_COUNT < 0
       OR observation.VOLUME_PHP < 0
       OR observation.CONFIRMED_COUNT < 0 OR observation.CONFIRMED_COUNT > observation.ALERT_COUNT
       OR observation.STR_FILED > observation.CONFIRMED_COUNT
       OR observation.REVIEW_COMPLETED > observation.REVIEW_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
