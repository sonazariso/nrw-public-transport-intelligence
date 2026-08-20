# 04-create-phase1-trip-stops.sql

```sql id="7a9p2m"
USE NRWTransportDW;
GO

/*
Purpose
-------
Create the Phase 1 working Trip-Stop dataset for NRW regional rail.

Business scope
--------------
Phase 1 contains only:

- RE
- RB
- S-Bahn

The full GTFS feed also contains bus, tram, metro/subway and other
services, but these are outside the current business scope.

Grain
-----
One row = one scheduled TripInstance at one StopSequence.

This is the first working dataset that matches the intended analytical
grain of the future fact table.

Why scope reduction was necessary
---------------------------------
Before materializing the Trip-Stop dataset, the expected row volume was
estimated.

Estimated full GTFS fact volume:
602,397,175 rows

Estimated RouteType 106/109 rail-like volume:
12,481,010 rows

Estimated final Phase 1 volume after applying the validated
RE/RB/S-Bahn classification:
8,029,550 rows

Therefore, the warehouse does not materialize the full multimodal GTFS
network in Phase 1.

The staging layer still preserves the complete source data, while the
working and warehouse layers apply the documented business scope.
*/


IF OBJECT_ID('wrk.Phase1TripStops', 'U') IS NOT NULL
    DROP TABLE wrk.Phase1TripStops;
GO

CREATE TABLE wrk.Phase1TripStops
(
    TripStopKey          BIGINT IDENTITY(1,1) NOT NULL,
    TripInstanceKey      BIGINT NOT NULL,

    ServiceDate          DATE NOT NULL,
    RouteId              NVARCHAR(255) NOT NULL,
    TransportMode        NVARCHAR(50) NOT NULL,

    StopId               NVARCHAR(255) NOT NULL,
    StopSequence         INT NOT NULL,

    ScheduledArrival     VARCHAR(8) NULL,
    ScheduledDeparture   VARCHAR(8) NULL,

    CONSTRAINT PK_wrk_Phase1TripStops
        PRIMARY KEY CLUSTERED (TripStopKey)
);
GO


/*
Load Phase 1 Trip-Stop rows
---------------------------
TripInstances provide the concrete service date.

RouteClassification restricts the dataset to validated Phase 1 routes.

StopTimes provides the ordered stop-level schedule for each trip.
*/

INSERT INTO wrk.Phase1TripStops
(
    TripInstanceKey,
    ServiceDate,
    RouteId,
    TransportMode,
    StopId,
    StopSequence,
    ScheduledArrival,
    ScheduledDeparture
)
SELECT
    ti.TripInstanceKey,
    ti.ServiceDate,
    ti.RouteId,
    rc.TransportMode,
    st.StopId,
    st.StopSequence,
    st.ArrivalTime,
    st.DepartureTime
FROM wrk.TripInstances ti

INNER JOIN wrk.RouteClassification rc
    ON ti.RouteId = rc.RouteId
   AND rc.IsPhase1 = 1

INNER JOIN stg.StopTimes st
    ON ti.TripId = st.TripId;
GO


/*
Validation performed during implementation
------------------------------------------

Observed total:
8,029,550 rows

Breakdown by transport mode:
RB      = 1,744,279
RE      = 2,536,487
S-Bahn  = 3,748,784

Grain validation:
TripInstanceKey + StopSequence duplicates = 0

Observed Phase 1 service-date coverage:
FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-12
ServiceDayCount  = 165

The shorter date range compared with wrk.ServiceDates is expected:
wrk.ServiceDates represents the complete GTFS feed, while this table
contains only the 65 validated Phase 1 routes.
*/


SELECT
    COUNT(*) AS Phase1TripStopCount
FROM wrk.Phase1TripStops;


SELECT
    TransportMode,
    COUNT(*) AS TripStopCount
FROM wrk.Phase1TripStops
GROUP BY TransportMode
ORDER BY TransportMode;


SELECT
    TripInstanceKey,
    StopSequence,
    COUNT(*) AS DuplicateCount
FROM wrk.Phase1TripStops
GROUP BY
    TripInstanceKey,
    StopSequence
HAVING COUNT(*) > 1;


SELECT
    MIN(ServiceDate) AS FirstServiceDate,
    MAX(ServiceDate) AS LastServiceDate,
    COUNT(DISTINCT ServiceDate) AS ServiceDayCount
FROM wrk.Phase1TripStops;
```
