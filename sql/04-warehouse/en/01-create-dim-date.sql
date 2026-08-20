# 01-create-dim-date.sql

```sql
USE NRWTransportDW;
GO

/*
Purpose
-------
Create the Date dimension used by the Phase 1 data warehouse.

Grain
-----
One row = one calendar date.

Why this dimension is needed
----------------------------
The fact table contains millions of scheduled Trip-Stop records.

A dedicated Date dimension allows reporting and filtering by:

- Date
- Day of week
- Week number
- Month
- Quarter
- Year
- Weekend / weekday

This avoids repeatedly calculating calendar attributes in analytical
queries or Power BI.

Phase 1 date range
------------------
The date range is based on the actual service coverage observed in
wrk.Phase1TripStops:

FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-12

Although wrk.ServiceDates continues until 2026-12-31, the selected
Phase 1 RE/RB/S-Bahn routes only contain Trip-Stop records through
2026-12-12.

Therefore, DimDate is aligned with the actual Phase 1 warehouse scope.
*/


IF OBJECT_ID('dw.DimDate', 'U') IS NOT NULL
    DROP TABLE dw.DimDate;
GO


CREATE TABLE dw.DimDate
(
    DateKey         INT NOT NULL,
    FullDate        DATE NOT NULL,

    DayNumber       TINYINT NOT NULL,
    DayName         NVARCHAR(20) NOT NULL,
    DayOfWeek       TINYINT NOT NULL,

    WeekNumber      TINYINT NOT NULL,

    MonthNumber     TINYINT NOT NULL,
    MonthName       NVARCHAR(20) NOT NULL,

    QuarterNumber   TINYINT NOT NULL,
    YearNumber      SMALLINT NOT NULL,

    IsWeekend       BIT NOT NULL,

    CONSTRAINT PK_dw_DimDate
        PRIMARY KEY CLUSTERED (DateKey),

    CONSTRAINT UQ_dw_DimDate_FullDate
        UNIQUE (FullDate)
);
GO


/*
Load calendar dates
-------------------
DateKey follows the standard YYYYMMDD warehouse format.

Example:

2026-07-01 -> 20260701
*/

;WITH DateSeries AS
(
    SELECT CAST('2026-07-01' AS DATE) AS FullDate

    UNION ALL

    SELECT DATEADD(DAY, 1, FullDate)
    FROM DateSeries
    WHERE FullDate < '2026-12-12'
)
INSERT INTO dw.DimDate
(
    DateKey,
    FullDate,
    DayNumber,
    DayName,
    DayOfWeek,
    WeekNumber,
    MonthNumber,
    MonthName,
    QuarterNumber,
    YearNumber,
    IsWeekend
)
SELECT
    YEAR(FullDate) * 10000
        + MONTH(FullDate) * 100
        + DAY(FullDate) AS DateKey,

    FullDate,

    DAY(FullDate) AS DayNumber,

    DATENAME(WEEKDAY, FullDate) AS DayName,

    DATEPART(WEEKDAY, FullDate) AS DayOfWeek,

    DATEPART(ISO_WEEK, FullDate) AS WeekNumber,

    MONTH(FullDate) AS MonthNumber,

    DATENAME(MONTH, FullDate) AS MonthName,

    DATEPART(QUARTER, FullDate) AS QuarterNumber,

    YEAR(FullDate) AS YearNumber,

    CASE
        WHEN DATENAME(WEEKDAY, FullDate) IN ('Saturday', 'Sunday')
            THEN 1
        ELSE 0
    END AS IsWeekend

FROM DateSeries
OPTION (MAXRECURSION 0);
GO


/*
Validation performed during implementation
------------------------------------------

Observed results:

DateCount        = 165
FirstDate        = 2026-07-01
LastDate         = 2026-12-12

The resulting dimension covers exactly the service-date range present
in the Phase 1 Trip-Stop dataset.
*/


SELECT
    COUNT(*) AS DateCount,
    MIN(FullDate) AS FirstDate,
    MAX(FullDate) AS LastDate
FROM dw.DimDate;


SELECT TOP (20)
    DateKey,
    FullDate,
    DayName,
    WeekNumber,
    MonthName,
    QuarterNumber,
    YearNumber,
    IsWeekend
FROM dw.DimDate
ORDER BY FullDate;
```
