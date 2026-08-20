# Data Architecture

## 1. Overview

The NRW Rail Intelligence project uses a layered data architecture designed to separate raw source ingestion, transformation logic, analytical warehouse structures, and reporting.

The current implemented architecture is:

```text
NRW OpenData GTFS
        |
        v
Raw GTFS Files
        |
        v
+-------------------+
|   stg - Staging   |
+-------------------+
        |
        v
+-------------------+
| wrk - Working     |
| Transformation    |
+-------------------+
        |
        v
+-------------------+
| dw - Data         |
| Warehouse         |
+-------------------+
        |
        v
dw.vTripStopAnalytics
        |
        v
Power BI
(Planned)
```

The project currently contains a complete scheduled-data pipeline from the NRW GTFS source through the analytical warehouse layer.

Actual operational data such as delays and cancellations has not yet been integrated.

---

## 2. Source Layer

### Status: Implemented

The initial source is the official NRW public transport GTFS dataset.

The downloaded GTFS feed contains:

- `agency.txt`
- `calendar.txt`
- `calendar_dates.txt`
- `feed_info.txt`
- `routes.txt`
- `shapes.txt`
- `stop_times.txt`
- `stops.txt`
- `transfers.txt`
- `trips.txt`

The raw files are preserved before transformation.

This ensures that:

- source data remains reproducible
- transformation logic can be rerun
- business filtering does not destroy original source information

The raw data is not committed to Git because some files are very large, especially `stop_times.txt`.

---

## 3. Staging Layer — `stg`

### Status: Implemented

The `stg` schema stores GTFS data in a relational SQL Server structure.

The staging layer is intentionally close to the source format.

Its main responsibilities are:

- loading GTFS files
- preserving source identifiers
- preserving source values
- enabling relational validation
- providing input for downstream transformations

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

Observed row counts include:

| Table | Rows |
|---|---:|
| `stg.Agency` | 76 |
| `stg.Routes` | 5,949 |
| `stg.Trips` | 474,978 |
| `stg.Stops` | 104,632 |
| `stg.Calendar` | 9,430 |
| `stg.CalendarDates` | 406,747 |
| `stg.StopTimes` | 10,907,141 |

A dedicated import table was used for `stop_times.txt` because the source file contains more than 10 million rows.

### Important design rule

The complete GTFS dataset is preserved in staging.

The Phase 1 RE/RB/S-Bahn business scope is not applied at ingestion time.

This allows future project phases to reuse the same source data for other modes such as bus, tram, or metro.

---

## 4. Working / Transformation Layer — `wrk`

### Status: Implemented

The `wrk` schema contains intermediate transformation structures.

Its purpose is to convert source-oriented GTFS data into business-oriented analytical data before loading the final warehouse.

The implemented transformation flow is:

```text
stg.Calendar
stg.CalendarDates
        |
        v
wrk.ServiceDates
        |
        +--------------------+
        |                    |
        v                    |
stg.Trips                    |
        |                    |
        v                    |
wrk.TripInstances            |
                             |
stg.Routes ------------------+
        |
        v
wrk.RouteClassification
        |
        v
stg.StopTimes
        |
        v
wrk.Phase1TripStops
        |
        v
wrk.vPhase1TripStopsNormalized
```

---

## 5. `wrk.ServiceDates`

### Status: Implemented

`wrk.ServiceDates` converts GTFS calendar definitions into explicit service dates.

### Grain

```text
One row = one ServiceId on one ServiceDate
```

It combines:

- recurring weekday rules from `stg.Calendar`
- added service dates from `stg.CalendarDates`
- removed service dates from `stg.CalendarDates`

Observed result:

```text
406,747 service-date rows
9,430 distinct ServiceIds
2026-07-01 to 2026-12-31
```

Duplicate `(ServiceId, ServiceDate)` combinations were checked and none were found.

---

## 6. `wrk.TripInstances`

### Status: Implemented

GTFS `trips.txt` contains reusable trip definitions rather than one physical row per operating date.

`wrk.TripInstances` expands those trip definitions across their actual service dates.

### Grain

```text
One row = one TripId operating on one ServiceDate
```

Observed result:

```text
26,356,341 trip instances
184 distinct service days
2026-07-01 to 2026-12-31
```

A surrogate key was introduced:

```text
TripInstanceKey BIGINT IDENTITY
```

The business key remains:

```text
TripId + ServiceDate
```

and is protected by a unique index.

### Design optimization

The initial design considered `TripId NVARCHAR(500)` as part of a composite clustered key.

SQL Server produced an index-key-size warning.

Source profiling showed:

```text
Minimum TripId length = 19
Maximum TripId length = 66
Average TripId length ≈ 44.41
```

The working-layer column was therefore reduced to `NVARCHAR(100)` and a numeric surrogate clustered key was used.

---

## 7. Phase 1 Route Classification

### Status: Implemented

The project initially expected standard GTFS railway type `route_type = 2`.

Profiling of the NRW feed showed that the relevant services use extended GTFS route types instead.

Observed relevant values:

```text
RouteType 106 = 52 routes
RouteType 109 = 123 routes
```

Further profiling produced the implemented Phase 1 rules:

```text
RouteType 106 + RE prefix -> RE
RouteType 106 + RB prefix -> RB
RouteType 109 + S prefix  -> S-Bahn
```

The resulting Phase 1 contains:

| Mode | Routes |
|---|---:|
| RE | 32 |
| RB | 20 |
| S-Bahn | 13 |
| **Total** | **65** |

A further 110 RouteType 109 records are retained as `Other Rail` but explicitly excluded from Phase 1.

This makes the exclusion auditable instead of silently dropping those routes.

---

## 8. `wrk.Phase1TripStops`

### Status: Implemented

Before creating the working Trip-Stop dataset, row volume was estimated.

Estimated full multimodal GTFS Trip-Stop volume:

```text
602,397,175 rows
```

Estimated final RE/RB/S-Bahn Phase 1 volume:

```text
8,029,550 rows
```

For this reason, multimodal data remains available in staging while only the validated Phase 1 scope is materialized downstream.

### Grain

```text
One row = one TripInstance at one StopSequence
```

Observed result:

| Mode | Trip-Stop Rows |
|---|---:|
| RB | 1,744,279 |
| RE | 2,536,487 |
| S-Bahn | 3,748,784 |
| **Total** | **8,029,550** |

Duplicate `(TripInstanceKey, StopSequence)` rows were checked and none were found.

Phase 1 service-date coverage is:

```text
2026-07-01 to 2026-12-12
165 distinct days
```

---

## 9. GTFS Time Normalization

### Status: Implemented

GTFS permits timetable values beyond `24:00:00`.

For example:

```text
24:00:00
25:15:00
26:30:00
```

These are valid GTFS values for services continuing after midnight.

Because SQL Server `TIME` cannot represent such values, raw GTFS time strings are preserved and analytical timestamps are calculated separately.

The implemented view is:

```text
wrk.vPhase1TripStopsNormalized
```

It provides:

```text
ScheduledArrivalDateTime
ScheduledDepartureDateTime
ArrivalDayOffset
DepartureDayOffset
```

Observed after-midnight Trip-Stop rows:

```text
139,241
```

Example:

```text
ServiceDate          : 2026-07-01
ScheduledArrival     : 24:00:00
Normalized timestamp : 2026-07-02 00:00:00
ArrivalDayOffset     : 1
```

---

## 10. Data Warehouse Layer — `dw`

### Status: Implemented

The `dw` schema contains the analytical Star Schema.

Current structure:

```text
                 dw.DimDate
                     |
                     |
dw.DimRoute --- dw.FactTripStop --- dw.DimStop
```

Implemented warehouse objects:

```text
dw.DimDate
dw.DimRoute
dw.DimStop
dw.FactTripStop
dw.vTripStopAnalytics
```

---

## 11. `dw.DimDate`

### Status: Implemented

### Grain

```text
One row = one calendar date
```

Current size:

```text
165 dates
2026-07-01 to 2026-12-12
```

Attributes include:

- date
- day number
- day name
- weekday number
- ISO week
- month
- quarter
- year
- weekend indicator

---

## 12. `dw.DimRoute`

### Status: Implemented

### Grain

```text
One row = one Phase 1 RouteId
```

Current size:

```text
65 routes
```

It contains:

- route business identifier
- route short name
- route long name
- transport mode
- agency identifier
- operator name
- source GTFS route type

All 65 Phase 1 routes have an operator name.

---

## 13. `dw.DimStop`

### Status: Implemented

### Grain

```text
One row = one StopId used by Phase 1
```

Current size:

```text
1,236 stops
```

Observed quality:

```text
Stops with ParentStation = 918
Missing stop names       = 0
Missing coordinates      = 0
```

Parent-station attributes support aggregation from platform-level stops to physical railway stations.

---

## 14. `dw.FactTripStop`

### Status: Implemented

### Grain

```text
One row = one TripInstance at one StopSequence
```

Current size:

```text
8,029,550 rows
```

The fact table references:

```text
DateKey
RouteKey
StopKey
```

and contains:

```text
TripInstanceKey
StopSequence
ScheduledArrivalDateTime
ScheduledDepartureDateTime
ArrivalDayOffset
DepartureDayOffset
```

The working-layer row count and fact-table row count were compared:

```text
wrk.Phase1TripStops = 8,029,550
dw.FactTripStop     = 8,029,550
```

No rows were lost during dimension-key resolution.

Duplicate `(TripInstanceKey, StopSequence)` combinations were also checked and none were found.

---

## 15. Warehouse Indexing

### Status: Implemented

Two analytical indexes were added after the fact-table load:

```text
IX_FactTripStop_DateRouteStop
(DateKey, RouteKey, StopKey)
```

and:

```text
IX_FactTripStop_TripInstance
(TripInstanceKey, StopSequence)
```

The indexes were intentionally created after the large fact-table load to avoid unnecessary index-maintenance overhead during insertion.

---

## 16. Referential Constraints

### Status: Planned

Logical warehouse relationships currently exist between:

```text
FactTripStop.DateKey  -> DimDate.DateKey
FactTripStop.RouteKey -> DimRoute.RouteKey
FactTripStop.StopKey  -> DimStop.StopKey
```

Physical foreign key constraints have not yet been implemented.

They must therefore not be considered part of the current implemented architecture.

---

## 17. Analytical View

### Status: Implemented

The following view provides a business-readable layer over the Star Schema:

```text
dw.vTripStopAnalytics
```

It combines the fact table with:

- date attributes
- route information
- operator information
- stop and parent-station information
- scheduled timestamps

Initial analytical queries have already been executed successfully for:

- scheduled stop volume by mode
- highest-volume routes
- highest-volume stations

This layer currently represents scheduled timetable supply only.

---

## 18. Power BI Layer

### Status: Planned

Power BI has not yet been connected to the warehouse.

The expected semantic model will use the warehouse Star Schema rather than the raw staging tables.

Potential scheduled-data analysis includes:

- service volume by day
- service volume by route
- service volume by transport mode
- station activity
- operator coverage
- weekday vs weekend service
- timetable activity by hour

The Power BI model will be documented separately after implementation.

---

## 19. Actual / Realtime Operational Data

### Status: Planned

The current warehouse contains scheduled GTFS data only.

It does not yet contain:

- actual arrival times
- actual departure times
- delays
- cancellations
- disruption events
- punctuality measures

A reliable official operational-data source must be identified before these metrics can be implemented.

Until such data is integrated, the project must describe its current metrics as scheduled-service or timetable analytics rather than operational performance metrics.

---

## 20. Current Architecture Status

As currently implemented:

```text
Official NRW GTFS
       |
       v
Raw files
       |
       v
stg schema
       |
       v
wrk transformation layer
       |
       v
Phase 1 RE / RB / S-Bahn dataset
       |
       v
GTFS time normalization
       |
       v
dw Star Schema
       |
       v
Analytical SQL View
```

The scheduled-data warehouse is implemented and validated.

The next architectural extensions are:

```text
Power BI                  -> Planned
Actual / realtime data    -> Planned
Delay / cancellation KPIs -> Planned
AI workflow               -> Planned
```
