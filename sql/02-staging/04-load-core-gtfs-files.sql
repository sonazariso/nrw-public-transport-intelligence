USE NRWTransportDW;
GO

/* =========================================================
   AGENCY
   ========================================================= */

TRUNCATE TABLE stg.Agency;
GO

CREATE TABLE #AgencyImport
(
    AgencyId NVARCHAR(100) NULL,
    AgencyName NVARCHAR(255) NULL,
    AgencyUrl NVARCHAR(500) NULL,
    AgencyTimezone NVARCHAR(100) NULL,
    AgencyLang NVARCHAR(20) NULL,
    AgencyFareUrl NVARCHAR(500) NULL,
    AgencyEmail NVARCHAR(255) NULL
);

BULK INSERT #AgencyImport
FROM 'C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit\agency.txt'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK,
    KEEPNULLS
);

INSERT INTO stg.Agency
(
    AgencyId,
    AgencyName,
    AgencyUrl,
    AgencyTimezone,
    AgencyLang,
    AgencyFareUrl,
    AgencyEmail
)
SELECT
    AgencyId,
    AgencyName,
    AgencyUrl,
    AgencyTimezone,
    AgencyLang,
    AgencyFareUrl,
    AgencyEmail
FROM #AgencyImport;

DROP TABLE #AgencyImport;
GO


/* =========================================================
   ROUTES
   ========================================================= */

TRUNCATE TABLE stg.Routes;
GO

BULK INSERT stg.Routes
FROM 'C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit\routes.txt'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK,
    KEEPNULLS
);
GO


/* =========================================================
   TRIPS
   ========================================================= */

TRUNCATE TABLE stg.Trips;
GO

BULK INSERT stg.Trips
FROM 'C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit\trips.txt'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK,
    KEEPNULLS
);
GO


/* =========================================================
   STOPS
   ========================================================= */

TRUNCATE TABLE stg.Stops;
GO

BULK INSERT stg.Stops
FROM 'C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit\stops.txt'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK,
    KEEPNULLS
);
GO


/* =========================================================
   CALENDAR
   ========================================================= */

TRUNCATE TABLE stg.Calendar;
GO

BULK INSERT stg.Calendar
FROM 'C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit\calendar.txt'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK,
    KEEPNULLS
);
GO


/* =========================================================
   CALENDAR DATES
   ========================================================= */

TRUNCATE TABLE stg.CalendarDates;
GO

BULK INSERT stg.CalendarDates
FROM 'C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit\calendar_dates.txt'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK,
    KEEPNULLS
);
GO


/* =========================================================
   VALIDATION COUNTS
   ========================================================= */

SELECT 'Agency' AS TableName, COUNT(*) AS RowCount FROM stg.Agency
UNION ALL
SELECT 'Routes', COUNT(*) FROM stg.Routes
UNION ALL
SELECT 'Trips', COUNT(*) FROM stg.Trips
UNION ALL
SELECT 'Stops', COUNT(*) FROM stg.Stops
UNION ALL
SELECT 'Calendar', COUNT(*) FROM stg.Calendar
UNION ALL
SELECT 'CalendarDates', COUNT(*) FROM stg.CalendarDates;
GO
