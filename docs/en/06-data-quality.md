# Data Quality

## 1. Overview

Data quality checks were executed at multiple stages of the NRW Rail Intelligence pipeline.

The validation strategy focuses on:

- referential consistency
- duplicate detection
- GTFS time validity
- transformation completeness
- grain preservation
- dimension completeness
- warehouse row-count reconciliation

Only checks that were actually executed and whose results were reviewed are documented as implemented and passed.

---

## 2. Staging Referential Integrity

### Status: Implemented and validated

Several source-level relationships were checked before building the transformation layer.

### StopTimes → Trips

Validation question:

```text
Does every StopTimes.TripId exist in stg.Trips?
```

Observed result:

```text
MissingTripReferences = 0
```

Conclusion:

All staged stop-time records reference an existing trip.

---

## 3. StopTimes → Stops

### Status: Implemented and validated

Validation question:

```text
Does every StopTimes.StopId exist in stg.Stops?
```

Observed result:

```text
MissingStopReferences = 0
```

Conclusion:

All staged stop-time records reference an existing stop.

---

## 4. Trips → Routes

### Status: Implemented and validated

Validation question:

```text
Does every Trips.RouteId exist in stg.Routes?
```

Observed result:

```text
MissingRouteReferences = 0
```

Conclusion:

All staged trips reference an existing route.

---

## 5. ServiceId Calendar Coverage

### Status: Implemented and validated

Validation question:

```text
Does every ServiceId used by stg.Trips have a calendar definition?
```

Observed result:

```text
ServiceIdsWithoutCalendarDefinition = 0
```

Conclusion:

All trip service identifiers are represented in the available calendar data.

---

## 6. StopTimes Grain Validation

### Status: Implemented and validated

The source StopTimes grain was checked using:

```text
TripId + StopSequence
```

Observed result:

```text
Duplicate combinations = 0
```

Conclusion:

No duplicate stop positions were found for the same source trip.

---

## 7. GTFS Time Profiling

### Status: Implemented and validated

GTFS permits timetable hours beyond 24.

The source stop-time fields were profiled.

Observed result:

```text
TimesAfter24 = 278,425
```

This was not treated as an error.

Values such as:

```text
24:00:00
25:15:00
26:30:00
```

are valid GTFS representations of service continuing after midnight.

---

## 8. GTFS Time Format Validation

### Status: Implemented and validated

Time strings were checked for invalid format patterns.

Observed result:

```text
InvalidTimeFormat = 0
```

Conclusion:

No malformed time values were detected by the executed format validation.

This result supported the later normalization logic.

---

## 9. ServiceDates Uniqueness

### Status: Implemented and validated

The grain of:

```text
wrk.ServiceDates
```

is:

```text
ServiceId + ServiceDate
```

Duplicate combinations were checked.

Observed result:

```text
0 duplicates
```

Conclusion:

Each service appears at most once on each resolved calendar date.

---

## 10. Removed Calendar Exceptions

### Status: Implemented and validated

GTFS `calendar_dates` rows with:

```text
ExceptionType = 2
```

represent removed service dates.

After constructing `wrk.ServiceDates`, the result was checked to ensure removed dates were not still present.

Observed result:

```text
RemovedServicesStillPresent = 0
```

Conclusion:

Calendar removal exceptions were correctly applied.

---

## 11. ServiceDates Coverage

### Status: Implemented and validated

Observed values:

```text
ServiceDateCount     = 406,747
DistinctServiceCount = 9,430
FirstServiceDate     = 2026-07-01
LastServiceDate      = 2026-12-31
```

These results were reviewed before continuing to TripInstance expansion.

---

## 12. TripId Profiling

### Status: Implemented and reviewed

Before finalizing the `wrk.TripInstances` index design, source TripId length was measured.

Observed results:

```text
Minimum TripId length = 19
Maximum TripId length = 66
Average TripId length ≈ 44.41
```

This check was used to replace an overly wide working-layer design.

The final working column became:

```text
TripId NVARCHAR(100)
```

---

## 13. TripInstances Volume and Coverage

### Status: Implemented and validated

Observed result:

```text
TripInstanceCount = 26,356,341
```

Coverage:

```text
FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-31
ServiceDayCount  = 184
```

The unique business-key index on:

```text
TripId + ServiceDate
```

was successfully created.

---

## 14. Route Classification Profiling

### Status: Implemented and reviewed

The route-type distribution was profiled before applying Phase 1 business rules.

Observed route counts:

| RouteType | Routes |
|---:|---:|
| 0 | 586 |
| 1 | 511 |
| 3 | 4,647 |
| 4 | 2 |
| 106 | 52 |
| 109 | 123 |
| 405 | 28 |

A key finding was that the expected standard railway value:

```text
RouteType = 2
```

was not present for the relevant services.

Further profiling showed:

```text
RouteType 106:
RE = 32
RB = 20

RouteType 109:
S-prefix routes = 13
Other profiled routes = 110
```

This directly informed the final business classification.

---

## 15. Route Classification Validation

### Status: Implemented and validated

Observed final classification:

| TransportMode | IsPhase1 | RouteCount |
|---|---:|---:|
| RE | 1 | 32 |
| RB | 1 | 20 |
| S-Bahn | 1 | 13 |
| Other Rail | 0 | 110 |

Observed:

```text
Phase1RouteCount = 65
```

Conclusion:

The implemented Phase 1 route scope contains exactly 65 validated routes.

---

## 16. Trip-Stop Volume Estimation

### Status: Implemented and reviewed

Before materializing the large Trip-Stop dataset, expected row volumes were estimated.

Observed estimates:

```text
Full multimodal GTFS:
602,397,175 rows

RouteType 106/109:
12,481,010 rows

Final Phase 1:
8,029,550 rows
```

This check was used as a performance and scope-control measure.

---

## 17. Phase1TripStops Row Count

### Status: Implemented and validated

Observed total:

```text
8,029,550
```

Mode breakdown:

| Mode | Rows |
|---|---:|
| RB | 1,744,279 |
| RE | 2,536,487 |
| S-Bahn | 3,748,784 |
| **Total** | **8,029,550** |

The mode totals reconcile exactly with the table total.

---

## 18. Phase1TripStops Grain Validation

### Status: Implemented and validated

The expected grain is:

```text
TripInstanceKey + StopSequence
```

Duplicate check result:

```text
0 duplicates
```

Conclusion:

The working Trip-Stop dataset preserves the intended analytical grain.

---

## 19. Phase 1 Date Coverage

### Status: Implemented and reviewed

Observed Phase 1 coverage:

```text
FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-12
ServiceDayCount  = 165
```

This is shorter than the complete `wrk.ServiceDates` range.

This difference was reviewed and interpreted as a consequence of the selected 65-route Phase 1 scope rather than automatically classified as a data-quality error.

---

## 20. GTFS After-Midnight Normalization

### Status: Implemented and validated

The normalized working view was tested using records with hours greater than or equal to 24.

Observed:

```text
AfterMidnightStopCount = 139,241
```

A reviewed example:

```text
ServiceDate              = 2026-07-01
ScheduledArrival         = 24:00:00
ScheduledArrivalDateTime = 2026-07-02 00:00:00
ArrivalDayOffset         = 1
```

Conclusion:

The transformation correctly converts GTFS after-midnight times while preserving the original service-day meaning.

---

## 21. DimDate Validation

### Status: Implemented and validated

Observed result:

```text
DateCount = 165
FirstDate = 2026-07-01
LastDate  = 2026-12-12
```

The dimension exactly matches the observed Phase 1 service-date coverage.

---

## 22. DimRoute Validation

### Status: Implemented and validated

Observed:

```text
RouteCount = 65
```

Mode distribution:

```text
RE      = 32
RB      = 20
S-Bahn  = 13
```

Operator completeness:

```text
MissingOperatorCount = 0
```

Conclusion:

All Phase 1 routes were loaded and all have an operator name.

---

## 23. DimStop Validation

### Status: Implemented and validated

Observed:

```text
StopCount = 1,236
```

Additional results:

```text
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0
```

Conclusion:

All selected Phase 1 stops have names and geographic coordinates.

---

## 24. Fact Table Row Reconciliation

### Status: Implemented and validated

The working layer and warehouse fact table were compared.

Observed:

```text
wrk.Phase1TripStops = 8,029,550
dw.FactTripStop     = 8,029,550
```

Conclusion:

No Trip-Stop records were lost during Date, Route, or Stop surrogate-key resolution.

---

## 25. Fact Table Grain Validation

### Status: Implemented and validated

Duplicate check:

```text
TripInstanceKey + StopSequence
```

Observed result:

```text
0 duplicates
```

Conclusion:

The final warehouse fact table preserves the expected grain.

---

## 26. Business-Level Reconciliation

### Status: Implemented and reviewed

The analytical view produced the same scheduled-stop distribution as the working dataset.

Observed:

```text
S-Bahn = 3,748,784
RE     = 2,536,487
RB     = 1,744,279
```

This provides an additional end-to-end consistency check after the Star Schema joins.

---

## 27. Checks Not Yet Recorded as Passed

The following checks are not documented as passed unless their results are explicitly executed and reviewed:

- full NULL profiling for all staging columns
- physical warehouse foreign-key validation
- Power BI model validation
- Actual/realtime data quality
- delay accuracy
- cancellation accuracy
- operational punctuality reconciliation

These remain future validation tasks.

---

## 28. Current Quality Summary

The implemented scheduled-data pipeline has passed the key validations required to continue into reporting:

```text
Source referential checks          -> Passed
StopTimes duplicate grain check    -> Passed
GTFS time-format validation        -> Passed
Service calendar resolution        -> Passed
Route classification validation    -> Passed
Trip-Stop grain validation         -> Passed
Dimension completeness checks      -> Passed
Fact row-count reconciliation      -> Passed
Fact grain validation              -> Passed
```

The current checks validate the scheduled-data warehouse only.

They do not validate actual railway operational performance because actual operational data has not yet been integrated.
