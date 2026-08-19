# Data Sources

## 1. Primary Dataset: NRW GTFS Scheduled Timetable Data

The primary source for the project is the official **Soll-Fahrplandaten NRW** dataset published through the German OpenData ÖPNV platform.

The dataset provides a GTFS Schedule feed covering public transport services across North Rhine-Westphalia (NRW). The official dataset page states that the feed is updated weekly, normally on Wednesdays at approximately 03:00. The feed is currently marked as Beta and the publisher notes that some content errors may still exist.

### Source Information

- Dataset: Soll-Fahrplandaten NRW
- Format: GTFS Schedule
- Coverage: North Rhine-Westphalia (NRW), Germany
- Source platform: OpenData ÖPNV
- Data providers: AVV, NWL, VRR, VRS
- License: Creative Commons
- Update frequency: Weekly
- Current project snapshot: July 2026

The archived snapshots available on the platform also make it possible to study historical timetable structures over time.

## 2. GTFS Files Used

The downloaded GTFS package contains the following files:

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

The current data warehouse implementation uses the following core files.

### agency.txt

Contains information about transport agencies and operators.

Current staging table:

`stg.Agency`

### routes.txt

Contains public transport route definitions.

Important fields include:

- route identifier
- agency identifier
- short route name
- long route name
- route type
- route display colors

Current staging table:

`stg.Routes`

### trips.txt

Defines individual scheduled journeys belonging to routes and services.

Current staging table:

`stg.Trips`

### stops.txt

Contains stop and station information, including geographic coordinates, platform information and parent-station relationships.

Current staging table:

`stg.Stops`

### stop_times.txt

Contains the scheduled arrival and departure of each trip at each stop.

This is the largest source file in the current dataset and contains approximately 10.9 million records after loading.

Current staging table:

`stg.StopTimes`

### calendar.txt

Defines the regular weekly service patterns and their validity periods.

Current staging table:

`stg.Calendar`

### calendar_dates.txt

Defines service-date exceptions, including individually added or removed service dates.

Current staging table:

`stg.CalendarDates`

### feed_info.txt

Contains metadata about the GTFS feed itself.

Current staging table:

`stg.FeedInfo`

## 3. Current Loaded Data Volume

The initial July 2026 GTFS snapshot produced the following staging volumes:

- Agencies: 76
- Routes: 5,949
- Trips: 474,978
- Stops: 104,632
- Service calendar records: 9,430
- Calendar exception records: 406,747
- Stop-time records: 10,907,141

These figures provide an initial validation baseline for future ETL executions.

## 4. GTFS Data Relationships

At a simplified level, the main GTFS relationships used in this project are:

`Agency → Route → Trip → Stop Time → Stop`

Trips are associated with service definitions through `service_id`, while `calendar.txt` and `calendar_dates.txt` determine the actual dates on which a service operates.

This relationship is fundamental to the current warehouse grain:

**One scheduled trip at one stop on one service date.**

## 5. Data Quality Considerations

The official NRW dataset is currently identified as a Beta feed, and the provider explicitly notes that content errors may occur.

For this reason, the ETL process will include dedicated data-quality checks such as:

- missing route references
- missing trip references
- missing stop references
- unexpected NULL values
- duplicated business identifiers
- invalid geographic coordinates
- invalid service-date relationships
- invalid stop sequence values

These checks will be documented separately in the Data Quality section of the project.

## 6. Planned Additional Data Sources

The current GTFS dataset contains scheduled data (`Soll-Daten`). It does not by itself provide the complete actual operational performance needed to calculate real delays and cancellations.

Future phases therefore plan to integrate additional authoritative sources.

### GTFS Realtime

GTFS Realtime can provide operational information such as:

- expected arrival and departure times
- delays
- trip updates
- service disruptions
- vehicle positions

GTFS Realtime will be evaluated as a possible source for building the actual-performance side of the warehouse.

### NRW Public Transport Quality Data

Official NRW SPNV quality sources will be evaluated for historical benchmarking of metrics such as:

- punctuality
- reliability
- service quality

These datasets can be used to validate and benchmark analytical results produced by the project.

### Deutsche Bahn APIs

Official Deutsche Bahn APIs may later be used for selected rail-related enrichment and validation use cases, such as timetable or station information.

They are currently considered supplementary sources rather than the primary data source for the NRW-wide warehouse.

## 7. Source References

Primary sources used for the project:

- OpenData ÖPNV – Soll-Fahrplandaten NRW
- Official GTFS Schedule specification
- OpenData portals of NRW transport associations
- Official NRW public transport quality information
- Deutsche Bahn API Marketplace

All external data sources used in production versions of the project will be documented together with their licensing, access method, update frequency and purpose.
