USE NRWTransportDW;
GO

/*
Purpose
-------
Create the final Phase 1 fact table at Trip-Stop grain.

Grain
-----
One row = one scheduled TripInstance at one StopSequence.

This grain was already validated in wrk.Phase1TripStops and is preserved
in the warehouse fact table.

Why this fact table is needed
-----------------------------
The working layer still stores business identifiers such as RouteId and StopId.

The warehouse fact table replaces those repeated text identifiers with compact
surrogate keys from:

- dw.DimDate
- dw.DimRoute
- dw.DimStop

This creates the central fact table of the Star Schema and prepares the model
for efficient analytical querying and Power BI reporting.

The fact table also stores normalized scheduled arrival/departure timestamps
and GTFS day offsets for services that continue after midnight.
*/


IF OBJECT_ID('dw.FactTripStop', 'U') IS NOT NULL
    DROP TABLE dw.FactTripStop;
GO


CREATE TABLE dw.FactTripStop
(
    FactTripStopKey              BIGINT IDENTITY(1,1) NOT NULL,

    DateKey                      INT NOT NULL,
    RouteKey                     INT NOT NULL,
    StopKey                      INT NOT NULL,

    TripInstanceKey              BIGINT NOT NULL,
    StopSequence                 INT NOT NULL,

    ScheduledArrivalDateTime     DATETIME2(0) NULL,
    ScheduledDepartureDateTime   DATETIME2(0) NULL,

    ArrivalDayOffset             TINYINT NULL,
    DepartureDayOffset           TINYINT NULL,

    CONSTRAINT PK_dw_FactTripStop
        PRIMARY KEY CLUSTERED (FactTripStopKey)
);
GO


/*
Why foreign keys were not added before the load
-----------------------------------------------
The fact table contains more than 8 million rows.

During the initial load, physical foreign key constraints were intentionally
not created yet in order to avoid per-row referential validation overhead.

Logical relationships are:

DateKey  -> dw.DimDate(DateKey)
RouteKey -> dw.DimRoute(RouteKey)
StopKey  -> dw.DimStop(StopKey)

After the load and row-level validation, referential constraints can be added
as a separate hardening step.
*/


INSERT INTO dw.FactTripStop
(
    DateKey,
    RouteKey,
    StopKey,
    TripInstanceKey,
    StopSequence,
    ScheduledArrivalDateTime,
    ScheduledDepartureDateTime,
    ArrivalDayOffset,
    DepartureDayOffset
)
SELECT
    d.DateKey,
    r.RouteKey,
    s.StopKey,
    p.TripInstanceKey,
    p.StopSequence,
    p.ScheduledArrivalDateTime,
    p.ScheduledDepartureDateTime,
    p.ArrivalDayOffset,
    p.DepartureDayOffset
FROM wrk.vPhase1TripStopsNormalized p

INNER JOIN dw.DimDate d
    ON p.ServiceDate = d.FullDate

INNER JOIN dw.DimRoute r
    ON p.RouteId = r.RouteId

INNER JOIN dw.DimStop s
    ON p.StopId = s.StopId;
GO


/*
Validation performed during implementation
------------------------------------------

Observed result:

FactRowCount = 8,029,550

Work vs Fact comparison:

wrk.Phase1TripStops = 8,029,550
dw.FactTripStop     = 8,029,550

The exact row-count match confirms that no Phase 1 Trip-Stop records were
lost during the joins to DimDate, DimRoute, or DimStop.

Grain validation:

TripInstanceKey + StopSequence duplicates = 0

Therefore, the intended Trip-Stop grain is preserved in the final fact table.
*/


SELECT
    COUNT(*) AS FactRowCount
FROM dw.FactTripStop;


SELECT
    (SELECT COUNT(*) FROM wrk.Phase1TripStops) AS WorkRowCount,
    (SELECT COUNT(*) FROM dw.FactTripStop) AS FactRowCount;


SELECT
    TripInstanceKey,
    StopSequence,
    COUNT(*) AS DuplicateCount
FROM dw.FactTripStop
GROUP BY
    TripInstanceKey,
    StopSequence
HAVING COUNT(*) > 1;
