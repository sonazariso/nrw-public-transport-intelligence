USE NRWTransportDW;
GO

/*
Purpose
-------
Create a business-friendly analytical view over the Phase 1 Star Schema.

Why this view is needed
-----------------------
The warehouse fact table is intentionally compact and stores surrogate keys:

- DateKey
- RouteKey
- StopKey

For validation, SQL analysis, and future Power BI work, analysts need readable
business attributes such as:

- ServiceDate
- RouteShortName
- TransportMode
- OperatorName
- StopName
- ParentStationName
- Scheduled timestamps

This view joins the fact table to its dimensions and exposes those attributes
without duplicating warehouse data.

Important
---------
This is a scheduled-service analytical view.

It does NOT represent actual operations, delays, cancellations, or passenger
counts.
*/


CREATE OR ALTER VIEW dw.vTripStopAnalytics
AS
SELECT
    f.FactTripStopKey,
    f.TripInstanceKey,
    f.StopSequence,

    d.FullDate AS ServiceDate,
    d.DayName,
    d.MonthName,
    d.WeekNumber,
    d.IsWeekend,

    r.RouteKey,
    r.RouteId,
    r.RouteShortName,
    r.TransportMode,
    r.OperatorName,

    s.StopKey,
    s.StopId,
    s.StopName,
    s.ParentStationName,
    s.PlatformCode,
    s.Latitude,
    s.Longitude,

    f.ScheduledArrivalDateTime,
    f.ScheduledDepartureDateTime,
    f.ArrivalDayOffset,
    f.DepartureDayOffset

FROM dw.FactTripStop f

INNER JOIN dw.DimDate d
    ON f.DateKey = d.DateKey

INNER JOIN dw.DimRoute r
    ON f.RouteKey = r.RouteKey

INNER JOIN dw.DimStop s
    ON f.StopKey = s.StopKey;
GO


/*
Business validation queries executed during implementation
----------------------------------------------------------

1. Scheduled stop volume by transport mode

Observed results:
S-Bahn = 3,748,784
RE     = 2,536,487
RB     = 1,744,279
*/

SELECT
    TransportMode,
    COUNT(*) AS ScheduledStopCount
FROM dw.vTripStopAnalytics
GROUP BY TransportMode
ORDER BY ScheduledStopCount DESC;


/*
2. Top routes by scheduled stop volume

Examples observed among the highest-volume routes:
S1  = 611,744
S11 = 593,650
S6  = 507,587

These values represent scheduled Trip-Stop rows,
not passengers and not unique train movements.
*/

SELECT TOP (10)
    RouteShortName,
    TransportMode,
    OperatorName,
    COUNT(*) AS ScheduledStopCount
FROM dw.vTripStopAnalytics
GROUP BY
    RouteShortName,
    TransportMode,
    OperatorName
ORDER BY ScheduledStopCount DESC;


/*
3. Top stations by scheduled stop volume

ParentStationName is preferred when available so that platform-level
StopIds can be aggregated to the physical station.

Examples observed:
Düsseldorf Hbf       = 162,531
Dortmund Hbf         = 139,004
Essen Hauptbahnhof   = 137,343
Köln Hbf             = 85,188

These figures are scheduled stop-event counts only.
*/

SELECT TOP (10)
    COALESCE(ParentStationName, StopName) AS StationName,
    COUNT(*) AS ScheduledStopCount
FROM dw.vTripStopAnalytics
GROUP BY
    COALESCE(ParentStationName, StopName)
ORDER BY ScheduledStopCount DESC;
