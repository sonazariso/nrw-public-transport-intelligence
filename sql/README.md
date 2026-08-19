# SQL Scripts

This directory contains the SQL Server scripts used to build and load the data platform for the **NRW Public Transport Intelligence** project.

The scripts are organized by implementation stage.

## Current Structure

```text id="v7b9cj"
sql/
├── 01-database/
│   └── 01-create-database-and-schemas.sql
│
├── 02-staging/
│   ├── 01-create-staging-tables.sql
│   ├── 02-create-stop-times-import.sql
│   ├── 03-load-stop-times.sql
│   └── 04-load-core-gtfs-files.sql
│
├── 03-transformation/
├── 04-warehouse/
└── README.md
```

## 01-database

Contains scripts for creating the SQL Server database and the main schemas used by the project.

Current database:

`NRWTransportDW`

Current schemas:

- `stg` – source-oriented staging data
- `wrk` – intermediate transformation and business logic
- `dw` – final analytical data warehouse

## 02-staging

Contains scripts for creating and loading the GTFS staging tables.

The current staging layer includes:

- Agency
- Routes
- Trips
- Stops
- Stop Times
- Calendar
- Calendar Dates
- Feed Information

The large `stop_times.txt` file is loaded through a dedicated helper table:

`stg.StopTimesImport`

The current snapshot contains approximately 10.9 million Stop Time records.

## 03-transformation

This directory will contain transformation scripts developed during the next phase of the project.

Planned transformations include:

- Service Date generation
- Calendar exception handling
- Route classification
- Operator normalization
- Stop and station normalization
- Preparation of data for dimensional loading

No transformation scripts have been implemented yet.

## 04-warehouse

This directory will contain the final Data Warehouse scripts.

Planned objects include dimensions such as:

- DimDate
- DimTime
- DimRoute
- DimTrip
- DimStop
- DimOperator
- DimTransportMode

The planned main fact table is:

`FactTripStop`

These objects have not been implemented yet.

## Local Data Paths

The current ingestion scripts use a local development path such as:

```text id="qbw8ws"
C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit\
```

This path is environment-specific and must be adjusted when the project is executed on another machine.

Raw GTFS data files are intentionally not stored in this GitHub repository because of their size and because they can be obtained from the original public data source.

## Execution Order

For the currently implemented stage, scripts should be executed in this order:

1. `01-database/01-create-database-and-schemas.sql`
2. `02-staging/01-create-staging-tables.sql`
3. `02-staging/02-create-stop-times-import.sql`
4. `02-staging/04-load-core-gtfs-files.sql`
5. `02-staging/03-load-stop-times.sql`

Further transformation and warehouse scripts will be added as those project phases are implemented.

## Project Principle

Only SQL logic that has actually been implemented should be stored as completed project code.

Planned functionality is documented separately and will be added to this directory when it is implemented and validated.
