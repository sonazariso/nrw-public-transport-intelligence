# Data Architecture

## 1. Architecture Overview

The project uses a layered data architecture to separate raw source data, staging data, transformation logic, analytical warehouse structures, and reporting.

The current architecture is:

```text
Official GTFS Source
        ↓
Raw Files
        ↓
SQL Server Staging Layer
        ↓
Working / Transformation Layer
        ↓
Data Warehouse Layer
        ↓
Power BI
```

The main goal of this architecture is to keep each processing stage independent, traceable, and easy to validate.

## 2. Raw Layer

The Raw Layer contains the original GTFS files exactly as downloaded from the official source.

Current location:

`C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit`

Typical files include:

- `agency.txt`
- `routes.txt`
- `trips.txt`
- `stops.txt`
- `stop_times.txt`
- `calendar.txt`
- `calendar_dates.txt`
- `feed_info.txt`

The Raw Layer is treated as immutable.

No business transformation is performed directly on these files.

Its purpose is to preserve the original source data for:

- reproducibility
- auditing
- reprocessing
- debugging
- historical comparison

## 3. SQL Server Database

The analytical database is:

`NRWTransportDW`

SQL Server is used as the main relational platform for ingestion, transformation, data-quality validation, and warehouse modeling.

The database currently contains three logical schemas:

- `stg`
- `wrk`
- `dw`

## 4. Staging Layer

The `stg` schema contains data loaded from the GTFS source with minimal transformation.

Current staging tables include:

- `stg.Agency`
- `stg.Routes`
- `stg.Trips`
- `stg.Stops`
- `stg.StopTimes`
- `stg.Calendar`
- `stg.CalendarDates`
- `stg.FeedInfo`

The primary goals of the staging layer are:

- preserve source values
- provide SQL-based access to GTFS data
- validate source structure
- detect data-quality problems
- support repeatable ETL processing

Business logic should not be embedded heavily in this layer.

## 5. Working / Transformation Layer

The `wrk` schema is intended for intermediate transformations and reusable business logic.

Examples of planned objects include:

- `wrk.ServiceDates`
- `wrk.RouteClassification`
- `wrk.NormalizedOperators`
- `wrk.NormalizedStops`
- `wrk.TripServiceDates`

This layer will resolve source-oriented structures into business-oriented structures.

Examples include:

- expanding calendar rules into actual service dates
- applying `calendar_dates` exceptions
- classifying transport modes
- normalizing operator names
- resolving parent station relationships
- preparing data for dimensional loading

The `wrk` layer is not intended for direct Power BI reporting.

## 6. Data Warehouse Layer

The `dw` schema will contain the final analytical star schema.

Planned dimensions include:

- `dw.DimDate`
- `dw.DimTime`
- `dw.DimRoute`
- `dw.DimTrip`
- `dw.DimStop`
- `dw.DimOperator`
- `dw.DimTransportMode`

The main planned fact table is:

`dw.FactTripStop`

The current analytical grain is:

**One scheduled trip at one stop on one service date.**

This structure supports analysis by:

- date
- time
- route
- trip
- stop
- operator
- transport mode

## 7. Power BI Layer

Power BI will connect to the Data Warehouse layer rather than directly to raw GTFS files.

This keeps reporting logic separate from ingestion and transformation logic.

Planned analytical outputs include:

- punctuality
- delays
- cancellations
- route performance
- stop performance
- operator performance
- peak-hour reliability
- historical trends

The Power BI model should remain as simple as possible and rely on the warehouse for most transformation and business logic.

## 8. Data Flow

The current end-to-end data flow is:

```text
OpenData ÖPNV
     ↓
GTFS ZIP Download
     ↓
Raw GTFS Text Files
     ↓
BULK INSERT
     ↓
stg Schema
     ↓
Data Quality Checks
     ↓
wrk Schema
     ↓
Business Transformations
     ↓
dw Star Schema
     ↓
Power BI
```

## 9. Design Principles

The project follows several architecture principles.

### Preserve Raw Data

Original source files are never modified.

### Separate Source and Business Logic

GTFS source structures are preserved in staging, while business transformations are handled later.

### Make ETL Repeatable

Loads and transformations should be reproducible and suitable for automation in future phases.

### Keep Reporting Independent

Power BI should consume curated warehouse data rather than implement core transformation logic itself.

### Support Future Sources

The architecture is designed to support additional sources such as:

- GTFS Realtime
- NRW quality datasets
- Deutsche Bahn APIs
- weather or incident data

These sources can be integrated without redesigning the entire solution.

## 10. Current Project Status

The current implementation has completed:

- database creation
- schema creation
- staging-table creation
- initial GTFS ingestion
- validation of several million source records

The next major steps are:

- data-quality validation
- working-layer transformations
- dimensional modeling
- fact-table creation
- Power BI modeling
