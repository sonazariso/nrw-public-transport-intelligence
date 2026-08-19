# Data Warehouse Design

## 1. Design Goal

The data warehouse is designed to support analytical reporting for public transport performance in North Rhine-Westphalia (NRW).

The model follows a dimensional star-schema approach and is intended to support Power BI reporting with clear relationships, reusable dimensions, and scalable fact tables.

The first implementation focuses on scheduled regional rail services:

- RE
- RB
- S-Bahn

Future phases may extend the model to:

- U-Bahn / Stadtbahn
- Tram
- Bus

## 2. Fact Table Grain

The most important design decision is the grain of the main fact table.

The selected grain is:

**One scheduled trip at one stop on one service date.**

Example:

A train operating as a specific Trip on 2026-07-15 and stopping at Köln Hbf creates one fact row for that stop.

If the same Trip stops at Düsseldorf Hbf, that creates another fact row.

If the same scheduled service operates on another day, new fact rows are created for that service date.

This grain provides enough detail for future analysis of:

- planned arrival and departure
- actual arrival and departure
- delay
- cancellation
- route performance
- station performance
- time-of-day performance
- delay propagation along a trip

## 3. Main Fact Table

The planned main fact table is:

`dw.FactTripStop`

Possible columns include:

- FactTripStopKey
- DateKey
- TripKey
- RouteKey
- StopKey
- OperatorKey
- TransportModeKey
- StopSequence
- PlannedArrivalTime
- PlannedDepartureTime
- ActualArrivalTime
- ActualDepartureTime
- ArrivalDelaySeconds
- DepartureDelaySeconds
- IsCancelled
- IsOnTime
- IsSeverelyDelayed

Actual operational columns will remain NULL until realtime or historical actual-performance data is integrated.

## 4. Date Dimension

Planned table:

`dw.DimDate`

The Date dimension will support filtering and trend analysis.

Typical attributes:

- DateKey
- FullDate
- Year
- Quarter
- Month
- MonthName
- WeekOfYear
- DayOfMonth
- DayOfWeek
- DayName
- IsWeekend

Additional NRW-specific attributes may later include:

- PublicHoliday
- SchoolHoliday
- HolidayName

## 5. Time Dimension

Planned table:

`dw.DimTime`

The Time dimension can support analysis by:

- hour
- minute
- time period
- morning peak
- evening peak
- off-peak period

Possible attributes:

- TimeKey
- Hour
- Minute
- TimeLabel
- TimePeriod
- IsPeakHour

## 6. Route Dimension

Planned table:

`dw.DimRoute`

The Route dimension will represent transport lines.

Possible attributes:

- RouteKey
- RouteId
- RouteShortName
- RouteLongName
- RouteType
- RouteColor
- TransportMode
- OperatorName

Examples:

- RE 1
- RB 48
- S 11

The source GTFS `route_type` is not sufficient on its own to distinguish all business-relevant route categories, so additional classification logic will be introduced.

## 7. Trip Dimension

Planned table:

`dw.DimTrip`

The Trip dimension represents an individual scheduled journey definition.

Possible attributes:

- TripKey
- TripId
- RouteKey
- ServiceId
- TripHeadsign
- TripShortName
- DirectionId
- ShapeId

This dimension allows multiple fact rows belonging to the same Trip to be analyzed together.

## 8. Stop Dimension

Planned table:

`dw.DimStop`

Possible attributes:

- StopKey
- StopId
- StopName
- Latitude
- Longitude
- LocationType
- ParentStation
- PlatformCode
- NvbwHstDhid

A later transformation step may distinguish:

- station
- platform
- stop position

This is important because GTFS may contain multiple stop records belonging to the same physical station.

## 9. Operator Dimension

Planned table:

`dw.DimOperator`

Possible attributes:

- OperatorKey
- SourceAgencyId
- OperatorName
- OperatorGroup
- TransportRegion

The source `agency.txt` data does not always represent a clean one-to-one business definition of operator.

For this reason, operator normalization will be performed in the working layer.

## 10. Transport Mode Dimension

Planned table:

`dw.DimTransportMode`

Possible values include:

- RE
- RB
- S-Bahn
- U-Bahn / Stadtbahn
- Tram
- Bus

Phase 1 will primarily use:

- RE
- RB
- S-Bahn

This dimension provides a business-friendly classification independent of raw GTFS route types.

## 11. Service Date Generation

GTFS does not directly contain one row for every active Trip date.

Instead, service availability is derived from:

- `calendar.txt`
- `calendar_dates.txt`

The warehouse therefore needs to generate actual service dates before loading the fact table.

Planned transformation:

`calendar + calendar_dates → wrk.ServiceDates`

This process must:

- expand weekday rules
- respect start and end dates
- add exception dates
- remove excluded dates

The result will represent the actual dates on which each `service_id` is active.

## 12. GTFS Time Handling

An important technical design decision concerns GTFS time values.

GTFS permits times greater than `24:00:00`.

For example:

`25:15:00`

This represents 01:15 on the following service day.

Because this value is not valid for the SQL Server `TIME` data type, raw GTFS arrival and departure times are stored as:

`VARCHAR(8)`

in the staging layer.

The transformation layer will later convert these values into analytical date/time representations while preserving the correct service-day relationship.

This design prevents loss or corruption of overnight service information.

## 13. Surrogate Keys

Final warehouse dimensions will use surrogate integer keys.

Examples:

- RouteKey
- StopKey
- TripKey
- OperatorKey
- TransportModeKey

The original GTFS identifiers will also be retained as business keys.

This provides:

- stable dimensional relationships
- better Power BI model performance
- independence from source identifier formats
- support for future source integration

## 14. Star Schema Concept

The intended model is conceptually:

```text
                    DimDate
                       |
                       |
DimRoute ---- FactTripStop ---- DimStop
                       |
                       |
                    DimTrip
                       |
                DimOperator
                       |
              DimTransportMode
```

The final implementation may adjust relationships where required, but the goal is to maintain a simple analytical model suitable for Power BI.

## 15. Future Actual Performance Data

The first warehouse version is based primarily on scheduled GTFS data.

Future realtime or historical operational data will extend the Fact table with fields such as:

- actual arrival
- actual departure
- delay seconds
- cancellation status

This will enable metrics such as:

- punctuality percentage
- average delay
- severe-delay percentage
- cancellation rate
- reliability score
- delay propagation

## 16. Design Principle

Business logic should be centralized in the SQL transformation and warehouse layers whenever practical.

Power BI should primarily perform:

- analytical measures
- visualization
- filtering
- business-facing reporting

rather than reconstructing complex source transformations inside Power Query or DAX.

This separation improves maintainability, transparency, and reproducibility.
