# ETL Process

## 1. Overview

The current ETL pipeline processes scheduled NRW GTFS data through four logical stages:

```text
Raw GTFS Files
      |
      v
Staging Layer (stg)
      |
      v
Transformation Layer (wrk)
      |
      v
Data Warehouse Layer (dw)
```

The current ETL implementation is focused on scheduled timetable data for:

- RE
- RB
- S-Bahn

Actual operational data has not yet been integrated.

---

## 2. ETL Design Principles

The ETL process follows these principles:

- preserve raw source data
- keep staging close to source structure
- apply business filtering after ingestion
- validate data before large transformations
- reduce data volume before warehouse materialization
- preserve GTFS-specific semantics such as times beyond 24:00:00
- use surrogate keys in the warehouse
- validate row counts between layers
- add reporting indexes after large loads

---

## 3. Step 1 — Raw GTFS Acquisition

### Status: Implemented

The official NRW GTFS dataset was downloaded from the NRW public transport open-data source.

The source package contains:

```text
agency.txt
calendar.txt
calendar_dates.txt
feed_info.txt
routes.txt
shapes.txt
stop_times.txt
stops.txt
transfers.txt
trips.txt
```

The raw files are preserved outside the database before ingestion.

The largest file is:

```text
stop_times.txt
```

with approximately 1.12 GB of source data.

Because of its size, the file was inspected using PowerShell rather than a standard text editor.

---

## 4. Step 2 — Database and Schema Preparation

### Status: Implemented

The SQL Server database is:

```text
NRWTransportDW
```

The main schemas are:

```text
stg
wrk
dw
```

Their responsibilities are:

| Schema | Purpose |
|---|---|
| `stg` | Source-oriented relational staging |
| `wrk` | Transformation and intermediate processing |
| `dw` | Analytical Star Schema |

---

## 5. Step 3 — GTFS Staging Load

### Status: Implemented

GTFS files were loaded into SQL Server staging tables.

Implemented staging tables include:

```text
stg.Agency
stg.Routes
stg.Trips
stg.Stops
stg.Calendar
stg.CalendarDates
stg.StopTimes
stg.StopTimesImport
stg.FeedInfo
```

Observed source row counts:

| Table | Rows |
|---|---:|
| `stg.Agency` | 76 |
| `stg.Routes` | 5,949 |
| `stg.Trips` | 474,978 |
| `stg.Stops` | 104,632 |
| `stg.Calendar` | 9,430 |
| `stg.CalendarDates` | 406,747 |
| `stg.StopTimes` | 10,907,141 |

---

## 6. Step 4 — Large StopTimes Import

### Status: Implemented

`stop_times.txt` required a dedicated load strategy because it contains more than 10 million rows.

A permanent import table was used:

```text
stg.StopTimesImport
```

The source file was first loaded into this import structure and then inserted into:

```text
stg.StopTimes
```

This separated raw file ingestion from the final staging structure.

Final observed `stg.StopTimes` row count:

```text
10,907,141
```

---

## 7. Step 5 — Staging Data Quality Checks

### Status: Implemented where actually executed

Before building the transformation layer, key referential checks were performed.

Observed results:

```text
Missing Trip references from StopTimes = 0
Missing Stop references from StopTimes = 0
Missing Route references from Trips    = 0
ServiceIds without calendar definition = 0
```

Duplicate `(TripId, StopSequence)` combinations in `stg.StopTimes` were also checked.

Observed result:

```text
0 duplicates
```

GTFS time format was also profiled.

Observed results:

```text
TimesAfter24     = 278,425
InvalidTimeFormat = 0
```

This confirmed that times beyond `24:00:00` are valid source behavior rather than malformed records.

---

## 8. Step 6 — Resolve Explicit Service Dates

### Status: Implemented

The first working-layer transformation creates:

```text
wrk.ServiceDates
```

Inputs:

```text
stg.Calendar
stg.CalendarDates
```

The transformation:

- expands recurring calendar ranges
- applies weekday flags
- adds ExceptionType = 1 dates
- removes ExceptionType = 2 dates

Grain:

```text
One row = one ServiceId on one ServiceDate
```

Observed result:

```text
406,747 rows
9,430 distinct ServiceIds
2026-07-01 to 2026-12-31
```

---

## 9. Step 7 — Expand Trips to Trip Instances

### Status: Implemented

The next transformation creates:

```text
wrk.TripInstances
```

Inputs:

```text
stg.Trips
wrk.ServiceDates
```

The join expands reusable GTFS trip definitions into concrete service-date trip instances.

Grain:

```text
One row = one TripId on one ServiceDate
```

Observed result:

```text
26,356,341 rows
184 distinct service days
```

---

## 10. Step 8 — TripId Key Optimization

### Status: Implemented

The first design considered a composite clustered key containing:

```text
TripId NVARCHAR(500)
ServiceDate
```

SQL Server warned that this key could exceed the allowed clustered-index key size.

TripId values were therefore profiled.

Observed lengths:

```text
Minimum = 19
Maximum = 66
Average ≈ 44.41
```

The working-layer design was changed to:

```text
TripId NVARCHAR(100)
TripInstanceKey BIGINT IDENTITY
```

A unique index preserves the business key:

```text
TripId + ServiceDate
```

---

## 11. Step 9 — Route Type Profiling

### Status: Implemented

Before materializing the large Trip-Stop dataset, source route types were profiled.

Observed route-type counts included:

```text
0   = 586
1   = 511
3   = 4,647
4   = 2
106 = 52
109 = 123
405 = 28
```

The expected standard rail value:

```text
RouteType = 2
```

was not present for the relevant NRW regional services.

The feed uses extended route-type values.

---

## 12. Step 10 — Phase 1 Route Classification

### Status: Implemented

Route classification was materialized in:

```text
wrk.RouteClassification
```

Implemented rules:

```text
106 + RE prefix -> RE
106 + RB prefix -> RB
109 + S prefix  -> S-Bahn
```

Observed classification:

| TransportMode | Phase 1 | Routes |
|---|---:|---:|
| RE | Yes | 32 |
| RB | Yes | 20 |
| S-Bahn | Yes | 13 |
| Other Rail | No | 110 |

Final Phase 1 route count:

```text
65
```

---

## 13. Step 11 — Estimate Transformation Volume

### Status: Implemented

Before building the Trip-Stop working table, expected row volume was estimated.

Full multimodal GTFS estimate:

```text
602,397,175 rows
```

RouteType 106/109 estimate:

```text
12,481,010 rows
```

Final validated Phase 1 estimate:

```text
8,029,550 rows
```

This analysis prevented unnecessary materialization of more than 600 million rows.

---

## 14. Step 12 — Add Transformation Performance Index

### Status: Implemented

Before the large Trip-Stop join, the following index was created:

```text
IX_stg_StopTimes_TripId
```

on:

```text
stg.StopTimes(TripId)
```

This supports the join between:

```text
wrk.TripInstances
```

and:

```text
stg.StopTimes
```

A second working-layer index was created on:

```text
wrk.TripInstances(RouteId, TripId)
```

including:

```text
TripInstanceKey
ServiceDate
```

This supports Phase 1 filtering and downstream joins.

---

## 15. Step 13 — Materialize Phase 1 Trip-Stop Data

### Status: Implemented

The main working dataset is:

```text
wrk.Phase1TripStops
```

Inputs:

```text
wrk.TripInstances
wrk.RouteClassification
stg.StopTimes
```

Grain:

```text
One row = one TripInstance at one StopSequence
```

Observed result:

```text
8,029,550 rows
```

Breakdown:

| Mode | Rows |
|---|---:|
| RB | 1,744,279 |
| RE | 2,536,487 |
| S-Bahn | 3,748,784 |

Duplicate grain rows:

```text
0
```

---

## 16. Step 14 — Normalize GTFS Scheduled Times

### Status: Implemented

GTFS permits times such as:

```text
24:00:00
25:10:00
26:35:00
```

Therefore, raw time values were not converted directly to SQL `TIME`.

The following view was created:

```text
wrk.vPhase1TripStopsNormalized
```

It calculates:

```text
ScheduledArrivalDateTime
ScheduledDepartureDateTime
ArrivalDayOffset
DepartureDayOffset
```

Observed after-midnight rows:

```text
139,241
```

Example validation:

```text
ServiceDate      = 2026-07-01
ScheduledArrival = 24:00:00
Result           = 2026-07-02 00:00:00
ArrivalDayOffset = 1
```

---

## 17. Step 15 — Build DimDate

### Status: Implemented

The first warehouse dimension created was:

```text
dw.DimDate
```

Phase 1 coverage:

```text
2026-07-01 to 2026-12-12
```

Observed row count:

```text
165
```

The dimension includes:

- day
- weekday
- ISO week
- month
- quarter
- year
- weekend indicator

---

## 18. Step 16 — Build DimRoute

### Status: Implemented

The route dimension was built from:

```text
stg.Routes
wrk.RouteClassification
stg.Agency
```

Only `IsPhase1 = 1` routes were loaded.

Observed row count:

```text
65
```

Distribution:

```text
RE      = 32
RB      = 20
S-Bahn  = 13
```

Missing operator names:

```text
0
```

---

## 19. Step 17 — Build DimStop

### Status: Implemented

The stop dimension contains only StopIds actually used by Phase 1.

Observed row count:

```text
1,236
```

Observed quality:

```text
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0
```

Parent-station data was resolved through a self-join on the source stop table.

---

## 20. Step 18 — Load FactTripStop

### Status: Implemented

The final fact table is:

```text
dw.FactTripStop
```

Source:

```text
wrk.vPhase1TripStopsNormalized
```

Dimension-key resolution:

```text
ServiceDate -> DimDate.DateKey
RouteId     -> DimRoute.RouteKey
StopId      -> DimStop.StopKey
```

Observed result:

```text
8,029,550 fact rows
```

Validation:

```text
WorkRowCount = 8,029,550
FactRowCount = 8,029,550
```

No records were lost.

Duplicate `(TripInstanceKey, StopSequence)`:

```text
0
```

---

## 21. Step 19 — Add Fact Reporting Indexes

### Status: Implemented

After the large fact-table load, two analytical indexes were created:

```text
IX_FactTripStop_DateRouteStop
(DateKey, RouteKey, StopKey)
```

and:

```text
IX_FactTripStop_TripInstance
(TripInstanceKey, StopSequence)
```

The indexes were added after loading to avoid index-maintenance overhead during bulk insertion.

---

## 22. Step 20 — Create Analytical View

### Status: Implemented

The final SQL analytical layer is:

```text
dw.vTripStopAnalytics
```

It joins:

```text
dw.FactTripStop
dw.DimDate
dw.DimRoute
dw.DimStop
```

The view exposes readable business attributes for validation and reporting.

---

## 23. Step 21 — Execute Business Validation Queries

### Status: Implemented

Initial warehouse queries were executed successfully.

Scheduled Stop Count by mode:

```text
S-Bahn = 3,748,784
RE     = 2,536,487
RB     = 1,744,279
```

Examples of high-volume routes:

```text
S1  = 611,744
S11 = 593,650
S6  = 507,587
```

Examples of high-volume stations:

```text
Düsseldorf Hbf      = 162,531
Dortmund Hbf        = 139,004
Essen Hauptbahnhof  = 137,343
Köln Hbf            = 85,188
```

These are scheduled Trip-Stop event counts only.

---

## 24. Current ETL Boundary

The implemented ETL currently ends at:

```text
dw.vTripStopAnalytics
```

The following stages remain planned:

```text
Power BI semantic model
Dashboard development
Actual/realtime data ingestion
Delay and cancellation transformations
AI-assisted analytical workflow
```

---

## 25. Current ETL Flow

The implemented ETL can be summarized as:

```text
NRW GTFS Raw Files
        |
        v
stg tables
        |
        v
Service calendar resolution
        |
        v
Trip instance expansion
        |
        v
Route classification
        |
        v
Phase 1 Trip-Stop materialization
        |
        v
GTFS time normalization
        |
        v
DimDate / DimRoute / DimStop
        |
        v
FactTripStop
        |
        v
Analytical indexes
        |
        v
dw.vTripStopAnalytics
```

This scheduled-data ETL is implemented and validated.
