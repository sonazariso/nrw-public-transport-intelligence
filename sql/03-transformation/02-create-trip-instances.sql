# 02-create-trip-instances.sql

```sql
USE NRWTransportDW;
GO

/*
Purpose
-------
Create one scheduled trip instance for every TripId + ServiceDate
combination.

Grain
-----
One row = one GTFS trip operating on one concrete service date.

Why this transformation is needed
---------------------------------
The GTFS trips table contains reusable trip definitions linked to a
ServiceId.

wrk.ServiceDates resolves ServiceId values into concrete calendar dates.

By joining stg.Trips to wrk.ServiceDates, each reusable GTFS trip
definition becomes one scheduled trip instance for a specific date.

Example
-------
TripId = T100
ServiceId = Special

If Special operates on:
2026-07-01
2026-07-02

the result becomes:

T100 + 2026-07-01
T100 + 2026-07-02
*/


/*
Implementation note: TripId profiling
-------------------------------------
The initial design used:

TripId NVARCHAR(500)
PRIMARY KEY (TripId, ServiceDate)

SQL Server produced a clustered-index key length warning because
NVARCHAR(500) can require up to 1000 bytes before ServiceDate is added.

The source data was therefore profiled before finalizing the design.

Observed TripId lengths:
- Minimum: 19
- Maximum: 66
- Average: approximately 44.41 characters

The working-layer TripId was consequently reduced to NVARCHAR(100),
which preserves a reasonable safety margin while avoiding unnecessarily
large indexes.

A BIGINT surrogate key is used as the clustered primary key, while
TripId + ServiceDate remains the unique business key.
*/


IF OBJECT_ID('wrk.TripInstances', 'U') IS NOT NULL
    DROP TABLE wrk.TripInstances;
GO

CREATE TABLE wrk.TripInstances
(
    TripInstanceKey BIGINT IDENTITY(1,1) NOT NULL,

    TripId          NVARCHAR(100) NOT NULL,
    ServiceDate     DATE NOT NULL,
    RouteId         NVARCHAR(255) NOT NULL,
    ServiceId       NVARCHAR(255) NOT NULL,
    DirectionId     INT NULL,
    TripHeadsign    NVARCHAR(500) NULL,

    CONSTRAINT PK_wrk_TripInstances
        PRIMARY KEY CLUSTERED (TripInstanceKey)
);
GO


/*
Business-key uniqueness
-----------------------
A TripId may operate on many dates, but the same TripId + ServiceDate
combination must not occur more than once.
*/

CREATE UNIQUE INDEX UX_wrk_TripInstances_TripId_ServiceDate
ON wrk.TripInstances
(
    TripId,
    ServiceDate
);
GO


/*
Load scheduled trip instances
-----------------------------
Join reusable GTFS trip definitions to the resolved service calendar.
*/

INSERT INTO wrk.TripInstances
(
    TripId,
    ServiceDate,
    RouteId,
    ServiceId,
    DirectionId,
    TripHeadsign
)
SELECT
    t.TripId,
    sd.ServiceDate,
    t.RouteId,
    t.ServiceId,
    t.DirectionId,
    t.TripHeadsign
FROM stg.Trips t
INNER JOIN wrk.ServiceDates sd
    ON t.ServiceId = sd.ServiceId;
GO


/*
Performance index
-----------------
Later transformations filter by RouteId and join StopTimes by TripId.

This index was added before generating the Phase 1 Trip-Stop dataset.
*/

CREATE INDEX IX_wrk_TripInstances_RouteId_TripId
ON wrk.TripInstances
(
    RouteId,
    TripId
)
INCLUDE
(
    TripInstanceKey,
    ServiceDate
);
GO


/*
Validation performed during implementation
------------------------------------------

Observed results:

TripInstanceCount = 26,356,341

Service-date coverage:
FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-31
ServiceDayCount  = 184

The TripId + ServiceDate unique index completed successfully.
*/


SELECT
    COUNT(*) AS TripInstanceCount
FROM wrk.TripInstances;


SELECT
    MIN(ServiceDate) AS FirstServiceDate,
    MAX(ServiceDate) AS LastServiceDate,
    COUNT(DISTINCT ServiceDate) AS ServiceDayCount
FROM wrk.TripInstances;


SELECT TOP (20)
    TripInstanceKey,
    TripId,
    ServiceDate,
    RouteId,
    ServiceId
FROM wrk.TripInstances
ORDER BY
    ServiceDate,
    TripInstanceKey;
```
