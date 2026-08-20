# 01-create-service-dates.sql

```sql
USE NRWTransportDW;
GO

/*
Purpose
-------
Create an explicit list of active service dates from the GTFS
calendar and calendar_dates staging tables.

Grain
-----
One row = one ServiceId on one ServiceDate.

Why this transformation is needed
---------------------------------
GTFS trips reference a ServiceId rather than a concrete calendar date.

The calendar table describes recurring weekly service patterns while
calendar_dates contains explicit additions and removals.

This working table resolves both sources into explicit dates that can
later be joined to trips.

GTFS calendar_dates exception_type:
1 = service added
2 = service removed
*/

IF OBJECT_ID('wrk.ServiceDates', 'U') IS NOT NULL
    DROP TABLE wrk.ServiceDates;
GO

CREATE TABLE wrk.ServiceDates
(
    ServiceId   NVARCHAR(255) NOT NULL,
    ServiceDate DATE NOT NULL,

    CONSTRAINT PK_wrk_ServiceDates
        PRIMARY KEY CLUSTERED
        (
            ServiceId,
            ServiceDate
        )
);
GO

;WITH DateSeries AS
(
    SELECT
        ServiceId,
        StartDate AS ServiceDate,
        EndDate,
        Monday,
        Tuesday,
        Wednesday,
        Thursday,
        Friday,
        Saturday,
        Sunday
    FROM stg.Calendar

    UNION ALL

    SELECT
        ServiceId,
        DATEADD(DAY, 1, ServiceDate),
        EndDate,
        Monday,
        Tuesday,
        Wednesday,
        Thursday,
        Friday,
        Saturday,
        Sunday
    FROM DateSeries
    WHERE ServiceDate < EndDate
),
CalendarServiceDates AS
(
    SELECT
        ServiceId,
        ServiceDate
    FROM DateSeries
    WHERE
           (DATENAME(WEEKDAY, ServiceDate) = 'Monday'    AND Monday    = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Tuesday'   AND Tuesday   = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Wednesday' AND Wednesday = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Thursday'  AND Thursday  = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Friday'    AND Friday    = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Saturday'  AND Saturday  = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Sunday'    AND Sunday    = 1)
),
AddedServiceDates AS
(
    SELECT
        ServiceId,
        CONVERT(DATE, ServiceDate, 112) AS ServiceDate
    FROM stg.CalendarDates
    WHERE ExceptionType = 1
),
Combined AS
(
    SELECT
        ServiceId,
        ServiceDate
    FROM CalendarServiceDates

    UNION

    SELECT
        ServiceId,
        ServiceDate
    FROM AddedServiceDates
),
RemovedServiceDates AS
(
    SELECT
        ServiceId,
        CONVERT(DATE, ServiceDate, 112) AS ServiceDate
    FROM stg.CalendarDates
    WHERE ExceptionType = 2
)
INSERT INTO wrk.ServiceDates
(
    ServiceId,
    ServiceDate
)
SELECT
    c.ServiceId,
    c.ServiceDate
FROM Combined c
LEFT JOIN RemovedServiceDates r
    ON  c.ServiceId   = r.ServiceId
    AND c.ServiceDate = r.ServiceDate
WHERE r.ServiceId IS NULL
OPTION (MAXRECURSION 0);
GO


/*
Validation performed during implementation
------------------------------------------
Observed result:

ServiceDateCount      = 406,747
DistinctServiceCount  = 9,430
FirstServiceDate      = 2026-07-01
LastServiceDate       = 2026-12-31

Additional checks:
- Duplicate ServiceId + ServiceDate rows: 0
- Removed exception dates still present: 0
*/

SELECT
    COUNT(*) AS ServiceDateCount,
    COUNT(DISTINCT ServiceId) AS DistinctServiceCount,
    MIN(ServiceDate) AS FirstServiceDate,
    MAX(ServiceDate) AS LastServiceDate
FROM wrk.ServiceDates;

SELECT
    ServiceId,
    ServiceDate,
    COUNT(*) AS DuplicateCount
FROM wrk.ServiceDates
GROUP BY
    ServiceId,
    ServiceDate
HAVING COUNT(*) > 1;

SELECT
    COUNT(*) AS RemovedServicesStillPresent
FROM wrk.ServiceDates sd
INNER JOIN stg.CalendarDates cd
    ON sd.ServiceId = cd.ServiceId
    AND sd.ServiceDate = CONVERT(DATE, cd.ServiceDate, 112)
WHERE cd.ExceptionType = 2;
```
