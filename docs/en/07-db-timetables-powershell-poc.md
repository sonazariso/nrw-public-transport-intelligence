# DB Timetables API & PowerShell Integration

## NRW Rail Performance Analytics

This document describes how the NRW Rail Performance Analytics project was connected to the official Deutsche Bahn Timetables API and how PowerShell was used to retrieve, inspect, parse, and compare planned and changed railway timetable data.

The objective of this integration is to extend the existing scheduled-data warehouse with operational railway information that can later be used to calculate:

- arrival delays
- departure delays
- platform changes
- cancellations
- punctuality KPIs
- scheduled vs. actual performance

---

# 1. Background

The first phase of the project was built using NRW GTFS scheduled timetable data.

The SQL Server data warehouse already contained the scheduled railway network for:

- RE — Regional Express
- RB — Regionalbahn
- S-Bahn

The existing warehouse provided information such as:

- service date
- route
- station
- stop sequence
- scheduled arrival
- scheduled departure

However, scheduled GTFS data alone cannot answer performance questions such as:

- Was the train delayed?
- How many minutes late was it?
- Was the platform changed?
- Was the service cancelled?
- Which route has the worst punctuality?
- Which station experiences the most delays?

Therefore, an additional source of operational data was required.

The official **Deutsche Bahn Timetables API** was selected for the Proof of Concept.

---

# 2. Why Deutsche Bahn Timetables API?

The DB Timetables API provides timetable information for railway stations.

Two API areas are particularly important for this project:

```text
/plan
```

Provides scheduled/planned timetable information.

And:

```text
/fchg
```

Provides changed timetable information.

This allows us to conceptually perform:

```text
Planned timetable
        +
Changed timetable
        ↓
Scheduled vs. Changed
        ↓
Delay calculation
```

For example:

```text
Planned Arrival : 11:15
Changed Arrival : 11:23
Delay           : 8 minutes
```

This is the foundation required for railway performance analysis.

---

# 3. Creating the DB API Application

The first step was to register on the Deutsche Bahn API Marketplace.

An application was created with a name similar to:

```text
NRW Rail Performance Analytics
```

The application was then subscribed to the **Timetables API**.

Two credentials are required by the API:

```text
DB-Client-ID
DB-Api-Key
```

## Security rule

These values must never be:

- committed to Git
- stored in README files
- included in screenshots
- hard-coded in SQL scripts
- published in source code

For the initial Proof of Concept, the credentials were stored only in PowerShell variables.

Example:

```powershell
$clientId = "YOUR_CLIENT_ID"
$apiKey   = "YOUR_API_KEY"
```

Then an HTTP header collection was created:

```powershell
$headers = @{
    "DB-Client-ID" = $clientId
    "DB-Api-Key"   = $apiKey
}
```

This object was reused for subsequent API calls.

---

# 4. Why PowerShell Was Used

PowerShell was used as a lightweight API exploration tool before implementing a permanent ingestion application.

This was useful because it allowed us to:

- send authenticated HTTP requests
- inspect raw responses
- work with XML
- test API endpoints quickly
- understand the data model
- validate identifiers
- test planned/changed matching
- calculate delay values

This approach was intentionally used before designing SQL tables for operational data.

The principle was:

> Inspect the real source data first, then design the warehouse schema.

This prevents designing tables based on assumptions about an external API.

---

# 5. Finding the Station EVA Number

The DB API uses an internal station identifier known as the **EVA number**.

We wanted to start with:

```text
Köln Hbf
```

Instead of manually guessing the identifier, the official station endpoint was queried.

PowerShell request:

```powershell
$response = Invoke-WebRequest `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/station/K%C3%B6ln%20Hbf" `
  -Headers $headers
```

The response was displayed with:

```powershell
$response.Content
```

The API returned XML containing:

```xml
<station
    name="Köln Hbf"
    eva="8000207"
    ...
/>
```

Therefore:

```text
Station : Köln Hbf
EVA     : 8000207
```

The EVA number became the technical station identifier used in subsequent API requests.

---

# 6. Avoiding the PowerShell Parsing Warning

The first `Invoke-WebRequest` generated a Windows PowerShell warning concerning webpage script parsing.

For subsequent requests, the following option was used:

```powershell
-UseBasicParsing
```

This avoids unnecessary webpage parsing behavior.

Example:

```powershell
Invoke-WebRequest `
    -UseBasicParsing `
    ...
```

---

# 7. Requesting the Planned Timetable

The next objective was to retrieve scheduled railway movements for Köln Hbf.

The EVA number was stored:

```powershell
$eva = "8000207"
```

The DB Timetables API plan endpoint expects a date and hour.

For the Proof of Concept:

```powershell
$date = "260822"
$hour = "11"
```

The date format is:

```text
yyMMdd
```

Therefore:

```text
260822
```

means:

```text
22 August 2026
```

The hour:

```text
11
```

represents the 11:00–11:59 timetable window.

The request was:

```powershell
$planResponse = Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/plan/$eva/$date/$hour" `
  -Headers $headers
```

The raw response was inspected using:

```powershell
$planResponse.Content
```

The API returned a large XML timetable containing many train movements.

Examples included:

- S-Bahn
- RE
- RB
- ICE
- other railway services

This confirmed that the API request was successful.

---

# 8. Parsing the Planned XML

Instead of manually reading hundreds of lines of XML, the response was converted into an XML object:

```powershell
[xml]$planXml = $planResponse.Content
```

Then only a few timetable records were inspected:

```powershell
$planXml.timetable.s |
    Select-Object -First 3 |
    Format-List *
```

This made the XML structure easier to understand.

A timetable stop is represented by an `<s>` element.

A simplified example looked like:

```xml
<s id="...">
    <tl
        c="S"
        n="32170"
    />

    <ar
        pt="2608221146"
        pp="10"
        l="S11"
    />

    <dp
        pt="2608221147"
        pp="10"
        l="S11"
    />
</s>
```

---

# 9. Important Planned-Timetable Fields

Several important attributes were identified.

## `id`

Example:

```text
2958834342628665585-2608220720-5
```

This is extremely important because the same ID can be used to associate planned and changed timetable information.

Conceptually:

```text
plan.id = change.id
```

---

## `tl`

`tl` contains train information.

Example:

```xml
<tl c="S" n="32170" />
```

Relevant attributes include:

```text
c = train category
n = train number
```

Example:

```text
c="S"
```

indicates an S-Bahn category.

---

## `ar`

`ar` represents arrival information.

Example:

```xml
<ar
    pt="2608221115"
    pp="4"
    fb="EUR 9411"
/>
```

Important attributes:

```text
pt = planned time
pp = planned platform
```

---

## `dp`

`dp` represents departure information.

Important attributes are similar to arrival:

```text
pt = planned departure time
pp = planned departure platform
```

---

## `l`

The `l` attribute can identify the service line.

Examples:

```text
S11
RE7
RB25
```

This is especially useful because the existing NRW GTFS warehouse already works with:

- RE
- RB
- S-Bahn

---

## `ppth`

The planned path may contain stations before or after the current station.

This can help describe the train's scheduled route.

---

# 10. Requesting Changed Timetable Information

After confirming that `/plan` worked, the next objective was to retrieve changed operational information.

The following endpoint was used:

```text
/fchg/{EVA}
```

For Köln Hbf:

```text
/fchg/8000207
```

The PowerShell request was:

```powershell
$changeResponse = Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/fchg/$eva" `
  -Headers $headers
```

The XML was then parsed:

```powershell
[xml]$changeXml = $changeResponse.Content
```

And a small number of records were displayed:

```powershell
$changeXml.timetable.s |
    Select-Object -First 3 |
    Format-List *
```

---

# 11. Changed-Time Field

A changed arrival record was identified with:

```xml
<ar ct="2608221123" />
```

The important attribute is:

```text
ct
```

which represents the changed time.

The value:

```text
2608221123
```

means:

```text
22 August 2026 11:23
```

This is different from the planned-time attribute:

```text
pt
```

Therefore:

```text
pt = planned time
ct = changed time
```

---

# 12. Finding a Record with Changed Arrival Time

A timetable record containing a changed arrival was selected:

```powershell
$changed = $changeXml.timetable.s |
    Where-Object { $_.ar.ct } |
    Select-Object -First 1
```

The record ID was displayed:

```powershell
$changed.id
```

And the changed arrival XML was inspected:

```powershell
$changed.ar.OuterXml
```

The result contained:

```xml
<ar ct="2608221123" />
```

The selected timetable ID was:

```text
2958834342628665585-2608220720-5
```

---

# 13. Matching Changed Data with Planned Data

This was the key Proof-of-Concept step.

The ID from the changed timetable was saved:

```powershell
$id = $changed.id
```

The planned timetable was then searched for exactly the same ID:

```powershell
$planned = $planXml.timetable.s |
    Where-Object { $_.id -eq $id } |
    Select-Object -First 1
```

The planned ID was checked:

```powershell
$planned.id
```

Then planned arrival information was displayed:

```powershell
$planned.ar.OuterXml
```

And changed arrival information:

```powershell
$changed.ar.OuterXml
```

Both records had the same timetable ID.

The planned arrival contained:

```xml
<ar
    pt="2608221115"
    pp="4"
    fb="EUR 9411"
    ...
/>
```

The changed arrival contained:

```xml
<ar ct="2608221123" />
```

Therefore:

```text
Planned arrival = 22.08.2026 11:15
Changed arrival = 22.08.2026 11:23
```

Delay:

```text
11:23 - 11:15 = 8 minutes
```

This successfully proved that planned and changed timetable information could be correlated.

---

# 14. Core Matching Logic

The essential integration concept is:

```text
/plan
    ↓
Timetable Stop ID
    ↓
ID matching
    ↑
Timetable Stop ID
    ↑
/fchg
```

Or technically:

```text
PlannedStop.Id = ChangedStop.Id
```

Then:

```text
ArrivalDelay =
ChangedArrivalTime
-
PlannedArrivalTime
```

Similarly:

```text
DepartureDelay =
ChangedDepartureTime
-
PlannedDepartureTime
```

---

# 15. Delay Calculation in PowerShell

A reusable PowerShell pattern was prepared to calculate delays for multiple matching records.

```powershell
$results = foreach ($changedStop in $changeXml.timetable.s) {

    $id = $changedStop.id

    $plannedStop = $planXml.timetable.s |
        Where-Object { $_.id -eq $id } |
        Select-Object -First 1

    if ($plannedStop -and $changedStop.ar.ct -and $plannedStop.ar.pt) {

        $plannedArrival = [datetime]::ParseExact(
            $plannedStop.ar.pt,
            "yyMMddHHmm",
            $null
        )

        $changedArrival = [datetime]::ParseExact(
            $changedStop.ar.ct,
            "yyMMddHHmm",
            $null
        )

        [PSCustomObject]@{
            Id                  = $id
            Line                = $plannedStop.ar.l
            Train               = $plannedStop.ar.fb
            PlannedArrival      = $plannedArrival
            ChangedArrival      = $changedArrival
            ArrivalDelayMinutes = [math]::Round(
                ($changedArrival - $plannedArrival).TotalMinutes,
                0
            )
            PlannedPlatform     = $plannedStop.ar.pp
            ChangedPlatform     = $changedStop.ar.cp
        }
    }
}
```

Results can be displayed using:

```powershell
$results |
    Select-Object -First 10 |
    Format-Table -AutoSize
```

Or, for easier inspection:

```powershell
$results |
    Select-Object -First 10 |
    Format-List
```

At the time of this documentation, the single-record planned/changed matching had already been validated successfully. The multi-record transformation above represents the next reusable extraction step.

---

# 16. Important API Field Mapping

The fields identified during the Proof of Concept can be summarized as follows:

| API Field | Meaning | Example |
|---|---|---|
| `s.id` | Timetable stop/event identifier | `2958834...-5` |
| `s.eva` | Station EVA identifier | `8000207` |
| `tl.c` | Train category | `S` |
| `tl.n` | Train number | `32170` |
| `ar.pt` | Planned arrival time | `2608221115` |
| `ar.ct` | Changed arrival time | `2608221123` |
| `ar.pp` | Planned arrival platform | `4` |
| `ar.cp` | Changed arrival platform, when present | e.g. changed track |
| `ar.l` | Line | `S11` |
| `ar.fb` | Service/train designation | `EUR 9411` |
| `dp.pt` | Planned departure time | timetable value |
| `dp.ct` | Changed departure time | operational value |
| `dp.pp` | Planned departure platform | timetable value |
| `dp.cp` | Changed departure platform | operational value |
| `ppth` | Planned station path | station sequence |

Not every attribute exists on every record. XML parsing must therefore handle optional fields safely.

---

# 17. Why This Proof of Concept Matters

This part of the project demonstrates several important Data Engineering skills.

## External API integration

The project communicates with a real external operational API.

## Authentication

API credentials are transmitted through HTTP headers.

## XML processing

The source returns XML rather than a simple CSV file.

## Data discovery

The source schema was explored before designing database tables.

## Identifier matching

Planned and changed datasets are correlated using the timetable stop ID.

## Transformation

Compact DB timestamps such as:

```text
2608221123
```

are converted into real `DateTime` values.

## Business calculation

Technical API attributes are transformed into a business KPI:

```text
Arrival Delay Minutes
```

## Data warehouse preparation

The Proof of Concept establishes the source structure required to design the future actual-performance layer in SQL Server.

---

# 18. Relationship with the Existing Data Warehouse

The project already contains scheduled GTFS data in SQL Server.

Current high-level architecture:

```text
NRW GTFS
   │
   ▼
stg
   │
   ▼
wrk
   │
   ▼
dw
   │
   ├── DimDate
   ├── DimRoute
   ├── DimStop
   └── FactTripStop
```

The DB Timetables API introduces a second source:

```text
DB Timetables API
       │
       ├── /station
       ├── /plan
       └── /fchg
       │
       ▼
PowerShell Proof of Concept
       │
       ▼
Future operational staging layer
       │
       ▼
Delay / Cancellation processing
       │
       ▼
Performance Analytics
```

Eventually both areas can be combined conceptually as:

```text
GTFS Scheduled Data
        +
DB Operational Data
        ↓
Scheduled vs. Actual
        ↓
NRW Rail Performance Analytics
```

---

# 19. Planned Next Steps

The next technical steps are:

1. Extract multiple matching `/plan` and `/fchg` records automatically.
2. Add departure-delay extraction.
3. investigate cancellation indicators.
4. investigate platform-change indicators.
5. Store raw API responses for traceability.
6. Design a SQL Server staging structure for DB API observations.
7. Periodically poll selected NRW stations.
8. Preserve observations historically because the API is operational rather than a complete historical archive.
9. Match operational DB events with the existing warehouse where technically reliable.
10. Calculate performance KPIs.
11. Compare project KPIs with official NRW SPNV quality statistics.
12. Visualize results in Power BI.

---

# 20. Interview Explanation

A concise way to explain this part of the project in an interview:

> I initially built the warehouse from NRW GTFS scheduled timetable data. However, scheduled data alone cannot measure railway performance. I therefore investigated the official Deutsche Bahn Timetables API. Before designing any new SQL tables, I created a PowerShell Proof of Concept to understand the real API structure. I authenticated using API headers, resolved Köln Hbf to its EVA station identifier, retrieved planned timetable data using the `/plan` endpoint, retrieved operational changes using `/fchg`, parsed the XML responses, and matched records using the timetable stop ID. I then verified that a planned arrival of 11:15 and a changed arrival of 11:23 represented an eight-minute delay. This validated the technical approach for adding scheduled-versus-actual railway performance data to the warehouse.

A shorter version:

> I used PowerShell as a data-discovery and API-prototyping tool before extending the SQL Server warehouse. It allowed me to validate the DB API, XML schema, business identifiers, and planned-versus-changed matching logic before committing to a database design.

---

# 21. Key Engineering Principle

The most important principle demonstrated by this phase was:

> **Do not design the analytical model based on assumptions about external data. Inspect and validate the real source first.**

PowerShell was deliberately used as the exploratory layer between the external DB API and the future SQL Server ingestion pipeline.

This reduced schema-design risk and provided a validated basis for the next phase of the NRW Rail Performance Analytics project.
