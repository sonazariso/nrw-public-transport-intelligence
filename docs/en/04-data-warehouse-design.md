# Data Warehouse Design

## 1. Overview

The Phase 1 data warehouse is designed as a Star Schema for scheduled regional rail analysis in North Rhine-Westphalia.

The implemented warehouse focuses on:

- RE
- RB
- S-Bahn

The current warehouse contains scheduled timetable data only.

It does not yet contain actual operational events such as delays, cancellations, or actual arrival/departure times.

---

## 2. Star Schema

### Status: Implemented

The implemented warehouse model is:

```text
                 +-------------+
                 | dw.DimDate  |
                 +-------------+
                       |
                       |
+-------------+  +------------------+  +-------------+
| dw.DimRoute |--| dw.FactTripStop |--| dw.DimStop  |
+-------------+  +------------------+  +-------------+
```

The fact table is the central analytical table.

The dimensions provide descriptive context for:

- date
- route
- operator
- stop
- station

---

## 3. Fact Table Grain

### Status: Implemented

The fact table grain is:

```text
One row = one scheduled TripInstance at one StopSequence
```

This means that each row represents one scheduled stop event within one concrete trip instance.

Example:

```text
TripInstance A
StopSequence 1 -> Köln Hbf
StopSequence 2 -> Düsseldorf Hbf
StopSequence 3 -> Essen Hbf
```

produces three fact rows.

This grain was validated before the warehouse load in:

```text
wrk.Phase1TripStops
```

and again after loading:

```text
dw.FactTripStop
```

No duplicate combinations of:

```text
TripInstanceKey + StopSequence
```

were found.

---

## 4. Why Trip-Stop Grain Was Selected

The Trip-Stop level provides enough detail for:

- route activity analysis
- stop and station activity
- timetable coverage
- service frequency analysis
- time-of-day analysis
- after-midnight service analysis
- future scheduled-vs-actual comparison

A higher-level Trip grain would lose stop-level detail.

A more detailed source-level multimodal grain would create unnecessary volume for Phase 1.

The selected grain therefore balances analytical usefulness with manageable warehouse size.

---

## 5. Fact Table

### `dw.FactTripStop`

### Status: Implemented

Current row count:

```text
8,029,550
```

Columns:

| Column | Purpose |
|---|---|
| `FactTripStopKey` | Surrogate row identifier |
| `DateKey` | Link to `dw.DimDate` |
| `RouteKey` | Link to `dw.DimRoute` |
| `StopKey` | Link to `dw.DimStop` |
| `TripInstanceKey` | Identifies one concrete scheduled trip instance |
| `StopSequence` | Ordered stop position within the trip |
| `ScheduledArrivalDateTime` | Normalized scheduled arrival timestamp |
| `ScheduledDepartureDateTime` | Normalized scheduled departure timestamp |
| `ArrivalDayOffset` | Number of days beyond the GTFS service date |
| `DepartureDayOffset` | Number of days beyond the GTFS service date |

The table uses:

```text
FactTripStopKey BIGINT IDENTITY
```

as its clustered primary key.

---

## 6. Degenerate Trip Identifier

### Status: Implemented

`TripInstanceKey` is stored directly in the fact table.

There is currently no separate `DimTrip` dimension.

This is intentional for the current Phase 1 model because the current reporting requirements primarily analyze:

- dates
- routes
- operators
- stops
- stations
- timetable events

`TripInstanceKey` therefore acts as a degenerate analytical identifier that allows stop rows belonging to the same scheduled trip to be grouped together.

A dedicated Trip dimension may be introduced later if trip-level descriptive attributes become important.

### Future Trip Dimension

Status:

```text
Planned only if required by future analytical needs
```

---

## 7. Date Dimension

### `dw.DimDate`

### Status: Implemented

Grain:

```text
One row = one calendar date
```

Current range:

```text
2026-07-01 to 2026-12-12
```

Current row count:

```text
165
```

Implemented attributes:

- `DateKey`
- `FullDate`
- `DayNumber`
- `DayName`
- `DayOfWeek`
- `WeekNumber`
- `MonthNumber`
- `MonthName`
- `QuarterNumber`
- `YearNumber`
- `IsWeekend`

`DateKey` uses the warehouse-friendly integer format:

```text
YYYYMMDD
```

Example:

```text
2026-07-01 -> 20260701
```

This makes the key:

- compact
- human-readable
- efficient for joins

---

## 8. Route Dimension

### `dw.DimRoute`

### Status: Implemented

Grain:

```text
One row = one Phase 1 RouteId
```

Current row count:

```text
65
```

Implemented attributes:

- `RouteKey`
- `RouteId`
- `RouteShortName`
- `RouteLongName`
- `TransportMode`
- `AgencyId`
- `OperatorName`
- `SourceRouteType`

Transport modes currently included:

```text
RE
RB
S-Bahn
```

The distribution is:

| Mode | Routes |
|---|---:|
| RE | 32 |
| RB | 20 |
| S-Bahn | 13 |
| **Total** | **65** |

No missing `OperatorName` values were found.

---

## 9. Route Surrogate Key

The source GTFS identifier:

```text
RouteId
```

is retained in the dimension as the business key.

The warehouse uses:

```text
RouteKey INT IDENTITY
```

as the surrogate key.

The fact table stores only `RouteKey`.

This avoids repeating potentially long text identifiers across more than eight million fact rows.

---

## 10. Stop Dimension

### `dw.DimStop`

### Status: Implemented

Grain:

```text
One row = one StopId used by the Phase 1 dataset
```

Current row count:

```text
1,236
```

Implemented attributes:

- `StopKey`
- `StopId`
- `StopName`
- `ParentStationId`
- `ParentStationName`
- `PlatformCode`
- `Latitude`
- `Longitude`
- `LocationType`
- `WheelchairBoarding`

Validation results:

```text
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0
```

---

## 11. Parent Station Modeling

GTFS can contain multiple platform-level StopIds for the same physical station.

Example:

```text
Platform Stop A
Platform Stop B
Platform Stop C
        |
        v
     Köln Hbf
```

For this reason, both:

```text
StopName
ParentStationName
```

are stored.

This allows analysis at:

- platform / stop level
- physical station level

The analytical view uses:

```text
COALESCE(ParentStationName, StopName)
```

when a station-level aggregation is required.

---

## 12. Stop Surrogate Key

The source business identifier:

```text
StopId
```

is preserved in the dimension.

The fact table references:

```text
StopKey INT IDENTITY
```

instead.

This significantly reduces repeated storage of long GTFS StopId values in the fact table.

---

## 13. Date Surrogate / Business Key Design

Unlike Route and Stop dimensions, `DimDate` does not use an identity-based surrogate key.

Instead:

```text
DateKey = YYYYMMDD
```

is used.

This is a common warehouse design because dates are stable and naturally map to a compact integer representation.

Example:

```text
2026-08-21 -> 20260821
```

---

## 14. Dimension Key Resolution

### Status: Implemented

The fact table was loaded from:

```text
wrk.vPhase1TripStopsNormalized
```

by resolving business identifiers to dimension keys.

Mappings:

```text
ServiceDate -> DimDate.DateKey
RouteId     -> DimRoute.RouteKey
StopId      -> DimStop.StopKey
```

All joins used `INNER JOIN`.

Validation showed:

```text
wrk.Phase1TripStops = 8,029,550
dw.FactTripStop     = 8,029,550
```

Therefore, no Phase 1 rows were lost during dimension key resolution.

---

## 15. GTFS Time Design

### Status: Implemented

GTFS allows times beyond midnight, such as:

```text
24:00:00
25:15:00
26:30:00
```

For this reason, the raw GTFS time string is not directly stored as SQL `TIME`.

Instead, the transformation layer creates:

```text
ScheduledArrivalDateTime
ScheduledDepartureDateTime
ArrivalDayOffset
DepartureDayOffset
```

Example:

```text
ServiceDate      = 2026-07-01
GTFS Time        = 24:00:00

Result:
2026-07-02 00:00:00
DayOffset = 1
```

The warehouse therefore receives analytical timestamps that preserve GTFS service-day semantics.

Observed after-midnight stop events:

```text
139,241
```

---

## 16. Fact Table Loading Strategy

### Status: Implemented

The fact table was loaded before adding reporting indexes.

This was intentional.

Creating all indexes before inserting more than eight million rows would force SQL Server to maintain those index structures during every insert.

The implemented order was:

```text
Create Fact Table
       |
       v
Load Fact Data
       |
       v
Validate Row Count
       |
       v
Validate Grain
       |
       v
Create Analytical Indexes
```

This is more efficient for bulk warehouse loading.

---

## 17. Fact Table Indexing

### Status: Implemented

Two nonclustered analytical indexes were created.

### Date / Route / Stop Index

```text
IX_FactTripStop_DateRouteStop
(DateKey, RouteKey, StopKey)
```

Purpose:

- date analysis
- route analysis
- stop analysis
- grouped reporting
- Power BI filtering patterns

### Trip Instance Index

```text
IX_FactTripStop_TripInstance
(TripInstanceKey, StopSequence)
```

Purpose:

- retrieve all stops of one trip
- preserve scheduled stop order
- analyze one trip instance efficiently

---

## 18. Foreign Key Constraints

### Status: Planned

Logical relationships exist:

```text
FactTripStop.DateKey
    -> DimDate.DateKey

FactTripStop.RouteKey
    -> DimRoute.RouteKey

FactTripStop.StopKey
    -> DimStop.StopKey
```

Physical foreign key constraints have not yet been created.

This is therefore documented as Planned, not Implemented.

If added later, they should be created only after validating the existing fact rows.

---

## 19. Analytical View

### `dw.vTripStopAnalytics`

### Status: Implemented

The warehouse also exposes a business-friendly analytical view.

It joins:

```text
FactTripStop
   +
DimDate
   +
DimRoute
   +
DimStop
```

The view exposes readable fields such as:

- service date
- route
- mode
- operator
- stop
- parent station
- coordinates
- scheduled arrival
- scheduled departure

It does not copy data.

It only provides a reusable relational join layer.

---

## 20. Initial Warehouse Findings

### Status: Implemented SQL validation only

Initial SQL queries returned the following scheduled stop-event volumes:

| Mode | Scheduled Stop Count |
|---|---:|
| S-Bahn | 3,748,784 |
| RE | 2,536,487 |
| RB | 1,744,279 |

Examples of high-volume routes observed:

```text
S1  = 611,744
S11 = 593,650
S6  = 507,587
```

Examples of high-volume stations observed:

```text
Düsseldorf Hbf      = 162,531
Dortmund Hbf        = 139,004
Essen Hauptbahnhof  = 137,343
Köln Hbf            = 85,188
```

These values represent:

```text
Scheduled Trip-Stop events
```

They do not represent:

- passenger counts
- unique train counts
- punctuality
- delays
- cancellations

---

## 21. Current Warehouse Scope

### Implemented

The current warehouse supports scheduled timetable analysis for:

```text
RE
RB
S-Bahn
```

### Not yet implemented

The warehouse does not currently include:

```text
Bus
Tram
Metro / U-Bahn
ICE / IC
Actual arrival/departure events
Delay metrics
Cancellation metrics
Passenger counts
```

The complete multimodal GTFS source remains preserved in the staging layer for possible future extensions.

---

## 22. Current Data Warehouse Status

The implemented warehouse contains:

```text
dw.DimDate        -> 165 rows
dw.DimRoute       -> 65 rows
dw.DimStop        -> 1,236 rows
dw.FactTripStop   -> 8,029,550 rows
```

Together they form the first implemented Star Schema of the project.

The model is now suitable for scheduled-data reporting and future Power BI integration.

Operational railway performance analysis will require an additional reliable actual/realtime data source.
