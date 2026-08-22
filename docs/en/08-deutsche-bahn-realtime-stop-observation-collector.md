# 8. Deutsche Bahn Realtime Stop Observation Collector

## 8.1 Objective

The objective of this stage was to extend the initial Deutsche Bahn Timetables API integration into a working realtime data collector that stores complete train-stop observations in SQL Server.

For every train stop event at a station, the collector is designed to capture:

- Planned arrival time
- Changed arrival time
- Arrival delay
- Arrival cancellation status
- Planned departure time
- Changed departure time
- Departure delay
- Departure cancellation status
- Planned platform
- Changed platform
- Snapshot capture time

The initial test station was:

```text
Station: Köln Hbf
EVA:     8000207
```

The collector was implemented and validated using PowerShell before moving toward a reusable automated collection process.

---

## 8.2 Realtime Staging Table

A dedicated staging table was created for Deutsche Bahn realtime observations:

```sql
stg.DbRealtimeStopObservation
```

The `stg` schema continues to be used for staging data, while the `Db` prefix identifies tables whose source is the Deutsche Bahn API.

The table contains the following columns:

```text
ObservationKey
DbEventId
StationEva
LineName
TrainName
PlannedArrival
ChangedArrival
ArrivalDelayMinutes
IsArrivalCancelled
PlannedDeparture
ChangedDeparture
DepartureDelayMinutes
IsDepartureCancelled
PlannedPlatform
ChangedPlatform
CapturedAt
```

### Column Purpose

`ObservationKey` is the internal surrogate key of the observation.

`DbEventId` contains the event identifier supplied by the Deutsche Bahn Timetables API.

`StationEva` identifies the station using its Deutsche Bahn EVA number.

`LineName` and `TrainName` contain train identification information when available from the API.

The arrival and departure columns store both planned and changed operational information.

`PlannedPlatform` and `ChangedPlatform` preserve the platform information received from the API.

`CapturedAt` records when the collector captured the observation.

---

## 8.3 Observation History Design

`stg.DbRealtimeStopObservation` is designed as an **observation-history table**, rather than as a table containing only the latest state of each train event.

This distinction is important.

A train event can be observed multiple times:

```text
13:00 snapshot -> 2-minute delay
13:05 snapshot -> 5-minute delay
13:10 snapshot -> 8-minute delay
```

Instead of updating the original row, future collector executions can append new observations with a new `CapturedAt` value.

This design makes it possible to analyze how operational conditions change over time.

For example, future analysis can investigate:

- How delays develop before arrival
- Whether delays increase or recover
- When platform changes occur
- When cancellations first appear
- How frequently operational information changes

---

## 8.4 Indexes

Indexes were created to support future observation-history queries.

The first index uses:

```text
(DbEventId, CapturedAt)
```

This supports analysis of the history of an individual Deutsche Bahn event.

The second index uses:

```text
(StationEva, CapturedAt)
```

This supports time-based analysis of observations collected for a particular station.

---

## 8.5 Deutsche Bahn API Endpoints

Two Deutsche Bahn Timetables API endpoints are required to construct a complete observation.

### Planned Timetable

The planned timetable endpoint is:

```text
/plan/{eva}/{date}/{hour}
```

It returns scheduled train-stop events for a particular station, date, and hour.

Important fields include:

```text
pt = Planned Time
pp = Planned Platform
```

Arrival information is available under the arrival element:

```text
ar
```

Departure information is available under:

```text
dp
```

---

## 8.6 Full Changes Endpoint

The full changes endpoint is:

```text
/fchg/{eva}
```

It provides current operational changes for train events at the station.

Important fields include:

```text
ct = Changed Time
cp = Changed Platform
cs = Status
```

A cancellation was identified using:

```text
cs = "c"
```

Arrival and departure cancellation states are handled independently.

---

## 8.7 Initial Köln Hbf API Test

The collector was tested using Köln Hbf:

```text
EVA = 8000207
```

During one validation run, the API returned:

```text
Plan stops:   63
Change stops: 945
```

The difference in counts is expected.

The `/plan` request was restricted to the requested timetable hour, while `/fchg` returned a broader collection of current changes associated with the station.

---

## 8.8 Matching Plan and Change Events

The planned timetable and full-change responses must be combined before a complete stop observation can be created.

Events are matched using the Deutsche Bahn event:

```text
id
```

This identifier is stored in SQL Server as:

```text
DbEventId
```

The matching logic can therefore be represented as:

```text
/plan event
     |
     | id
     v
/fchg event
```

During the validation test:

```text
Plan events: 63
Matched:     63
Not matched: 0
```

All 63 planned events therefore had corresponding entries in the `/fchg` response during that particular snapshot.

The collector must still support unmatched events because a future API response may not necessarily contain a change record for every planned event.

---

## 8.9 Deutsche Bahn Time Format

The timetable API returns time values using the following format:

```text
yyMMddHHmm
```

For example:

```text
2608221303
```

represents:

```text
2026-08-22 13:03
```

A PowerShell helper function was created to convert these values into .NET `DateTime` values:

```powershell
function Convert-DbTime {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return [datetime]::ParseExact(
        $Value,
        "yyMMddHHmm",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}
```

If the API value is missing, the function returns `$null`.

This preserves the difference between missing operational information and an actual known time.

---

## 8.10 Arrival Delay Calculation

Arrival delay is calculated only when both planned and changed arrival times are available.

For example:

```text
Planned Arrival: 13:03
Changed Arrival: 13:04
```

produces:

```text
ArrivalDelayMinutes = 1
```

The PowerShell calculation is:

```powershell
$arrivalDelayMinutes =
    if ($plannedArrival -and $changedArrival) {
        [int](($changedArrival - $plannedArrival).TotalMinutes)
    }
    else {
        $null
    }
```

A real API event was successfully validated with:

```text
PlannedArrival      : 2026-08-22 13:03
ChangedArrival      : 2026-08-22 13:04
ArrivalDelayMinutes : 1
```

---

## 8.11 Departure Delay Calculation

Departure delay follows the same principle:

```powershell
$departureDelayMinutes =
    if ($plannedDeparture -and $changedDeparture) {
        [int](($changedDeparture - $plannedDeparture).TotalMinutes)
    }
    else {
        $null
    }
```

It is important not to convert missing changed times into zero-minute delays.

The following states have different meanings:

```text
0    = operational information exists and there is no delay
NULL = insufficient information exists to calculate the delay
```

Preserving this distinction is important for future analytical accuracy.

---

## 8.12 Cancellation Handling

Arrival and departure cancellations are evaluated separately.

Arrival cancellation:

```powershell
$isArrivalCancelled =
    ($changeStop.ar.cs -eq "c")
```

Departure cancellation:

```powershell
$isDepartureCancelled =
    ($changeStop.dp.cs -eq "c")
```

Real cancelled events were found during testing.

Some cancelled events did not contain a changed arrival or departure time.

The collector deliberately keeps these values as `NULL` instead of generating an artificial changed time or delay.

---

## 8.13 Platform Information

Planned platform information is obtained primarily from the arrival element:

```text
ar.pp
```

If arrival platform information is unavailable, departure platform information is used:

```text
dp.pp
```

The same fallback strategy is used for changed platform information:

```text
ar.cp
```

followed by:

```text
dp.cp
```

The staging table stores the raw planned and changed platform values.

A separate `PlatformChanged` column was deliberately not added.

Platform changes can be derived analytically:

```sql
CASE
    WHEN PlannedPlatform IS NOT NULL
     AND ChangedPlatform IS NOT NULL
     AND PlannedPlatform <> ChangedPlatform
    THEN 1
    ELSE 0
END
```

This keeps the staging table focused on source observations while derived analytical attributes can be created later in the data warehouse or reporting layer.

---

## 8.14 Full Stop Snapshot

After combining `/plan` and `/fchg`, each event is transformed into a complete observation containing:

```text
DbEventId
StationEva
LineName
TrainName

PlannedArrival
ChangedArrival
ArrivalDelayMinutes
IsArrivalCancelled

PlannedDeparture
ChangedDeparture
DepartureDelayMinutes
IsDepartureCancelled

PlannedPlatform
ChangedPlatform

CapturedAt
```

This means arrival, departure, cancellation, and platform information are stored together in a single observation row for the event.

---

## 8.15 SQL NULL Handling

Several API fields are optional.

Examples include:

```text
ChangedArrival
ChangedDeparture
ArrivalDelayMinutes
DepartureDelayMinutes
ChangedPlatform
```

When passing nullable values from PowerShell to SQL Server parameters, a helper function is used:

```powershell
function DbValue {
    param($Value)

    if ($null -eq $Value) {
        return [DBNull]::Value
    }

    return $Value
}
```

This ensures that missing API values are correctly stored as SQL `NULL`.

---

## 8.16 Initial Arrival-Only Collector

Before implementing the complete snapshot collector, an arrival-only PowerShell collector was tested.

It successfully inserted:

```text
54 arrival observations
```

into:

```sql
stg.DbRealtimeStopObservation
```

This initial test confirmed:

- Deutsche Bahn API connectivity
- PowerShell XML processing
- SQL Server connectivity
- Integrated Security
- `TrustServerCertificate`
- Parameterized SQL insertion
- Correct handling of nullable API values

After this test succeeded, the arrival-only rows were removed so that the complete collector could be validated against a clean table.

---

## 8.17 Full Collector Test

Before testing the full collector, the staging table was cleared:

```sql
TRUNCATE TABLE stg.DbRealtimeStopObservation;
```

The full snapshot logic was then executed.

It successfully inserted:

```text
Inserted snapshots: 63
```

This represented all 63 events returned by the selected Köln Hbf `/plan` request.

---

## 8.18 PowerShell Validation

Before insertion, the generated PowerShell snapshot collection was validated.

The results were:

```text
TotalSnapshots        : 63
WithArrival           : 59
WithDeparture         : 57
ArrivalCancelled      : 2
DepartureCancelled    : 2
WithChangedPlatform   : 12
PlatformChanged       : 12
```

This confirmed that the collector successfully handled multiple types of train-stop events rather than only arrival records.

---

## 8.19 SQL Server Validation

The inserted data was independently validated inside SQL Server.

The SQL results were:

```text
TotalRows             : 63
WithArrival           : 59
WithDeparture         : 57
ArrivalCancelled      : 2
DepartureCancelled    : 2
WithChangedPlatform   : 12
PlatformChanged       : 12
```

The SQL results exactly matched the PowerShell results.

This validated the complete data path:

```text
Deutsche Bahn Timetables API
            |
            v
      PowerShell Collector
            |
            v
      Event ID Matching
            |
            v
    Full Stop Snapshot
            |
            v
 SQL Server Staging Layer
```

---

## 8.20 Real Data Quality Validation

The stored records were also manually inspected rather than relying only on row counts.

Real delays were observed, including examples such as:

```text
1 minute
2 minutes
3 minutes
7 minutes
15 minutes
```

The dataset also contained real examples of:

- Arrival delays
- Departure delays
- Arrival cancellations
- Departure cancellations
- Platform changes
- Arrival-only events
- Departure-only events
- Cancelled events without changed times

For example, cancelled events could legitimately contain:

```text
IsArrivalCancelled  = 1
ChangedArrival      = NULL
ArrivalDelayMinutes = NULL
```

This is considered correct.

The collector does not generate artificial changed times or zero delays when operational information is unavailable.

---

## 8.21 Current Status

The proof-of-concept Full Realtime Stop Observation Collector has been successfully validated for Köln Hbf.

The following functionality is now working:

- Deutsche Bahn `/plan` retrieval
- Deutsche Bahn `/fchg` retrieval
- Event matching using DB event IDs
- Planned arrival extraction
- Changed arrival extraction
- Arrival delay calculation
- Planned departure extraction
- Changed departure extraction
- Departure delay calculation
- Arrival cancellation detection
- Departure cancellation detection
- Planned platform extraction
- Changed platform extraction
- SQL `NULL` handling
- Full observation creation
- SQL Server insertion
- PowerShell-side validation
- SQL Server-side validation

The staging table is therefore ready to begin collecting historical realtime observations.

---

## 8.22 Next Step

The current implementation was developed and validated interactively in PowerShell.

The next stage is to convert this logic into a reusable collector script, for example:

```text
DbRealtimeCollector.ps1
```

The intended collection pipeline is:

```text
Current Hour /plan
        +
Next Hour /plan
        +
      /fchg
        |
        v
Event Deduplication
        |
        v
Matching by DbEventId
        |
        v
Full Snapshot Creation
        |
        v
Append to
stg.DbRealtimeStopObservation
```

From this point forward, the staging table should **not be truncated during normal collection**.

Repeated collector executions will instead append observations so that the project can build a historical dataset of how train delays, cancellations, and platform information evolve over time.
