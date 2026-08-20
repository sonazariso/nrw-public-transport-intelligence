# 05-create-normalized-trip-stop-view.sql

```sql
USE NRWTransportDW;
GO

/*
Purpose
-------
Normalize GTFS scheduled times into real SQL Server DATETIME2 values
without modifying the original GTFS time strings.

Why normalization is needed
---------------------------
GTFS allows service times greater than or equal to 24:00:00.

Examples:
24:00:00
25:10:00
26:35:00

These values are valid in GTFS because they represent service continuing
after midnight while still belonging to the previous service day.

SQL Server TIME does not accept values such as 25:10:00.

Therefore, the raw GTFS time values remain preserved as text, while this
view derives analytical DATETIME2 values.

Example
-------
ServiceDate      = 2026-07-01
ScheduledArrival = 25:10:00

Normalized result:
ScheduledArrivalDateTime = 2026-07-02 01:10:00
ArrivalDayOffset         = 1
*/


CREATE OR ALTER VIEW wrk.vPhase1TripStopsNormalized
AS
SELECT
    TripStopKey,
    TripInstanceKey,
    ServiceDate,
    RouteId,
    TransportMode,
    StopId,
    StopSequence,

    ScheduledArrival,
    ScheduledDeparture,

    DATEADD
    (
        SECOND,
          CONVERT(INT, LEFT(ScheduledArrival, 2)) * 3600
        + CONVERT(INT, SUBSTRING(ScheduledArrival, 4, 2)) * 60
        + CONVERT(INT, RIGHT(ScheduledArrival, 2)),
        CAST(ServiceDate AS DATETIME2(0))
    ) AS ScheduledArrivalDateTime,

    DATEADD
    (
        SECOND,
          CONVERT(INT, LEFT(ScheduledDeparture, 2)) * 3600
        + CONVERT(INT, SUBSTRING(ScheduledDeparture, 4, 2)) * 60
        + CONVERT(INT, RIGHT(ScheduledDeparture, 2)),
        CAST(ServiceDate AS DATETIME2(0))
    ) AS ScheduledDepartureDateTime,

    CONVERT(INT, LEFT(ScheduledArrival, 2)) / 24
        AS ArrivalDayOffset,

    CONVERT(INT, LEFT(ScheduledDeparture, 2)) / 24
        AS DepartureDayOffset

FROM wrk.Phase1TripStops;
GO


/*
Validation performed during implementation
------------------------------------------

Observed after-midnight stop count:
139,241

Example validated transformation:

ServiceDate                  = 2026-07-01
ScheduledArrival             = 24:00:00
ScheduledArrivalDateTime     = 2026-07-02 00:00:00
ArrivalDayOffset             = 1

This confirmed that GTFS after-midnight service times are converted
correctly while retaining their original service-date semantics.
*/


SELECT TOP (30)
    ServiceDate,
    ScheduledArrival,
    ScheduledArrivalDateTime,
    ArrivalDayOffset,
    TransportMode,
    RouteId,
    StopId
FROM wrk.vPhase1TripStopsNormalized
WHERE ArrivalDayOffset > 0
ORDER BY
    ServiceDate,
    ScheduledArrivalDateTime;


SELECT
    COUNT(*) AS AfterMidnightStopCount
FROM wrk.vPhase1TripStopsNormalized
WHERE ArrivalDayOffset > 0
   OR DepartureDayOffset > 0;
```
