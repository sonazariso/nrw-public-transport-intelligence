USE NRWTransportDW;
GO

/*
Purpose
-------
Create the Stop dimension for the Phase 1 data warehouse.

Grain
-----
One row = one GTFS StopId used by the Phase 1 Trip-Stop dataset.

Why this dimension is needed
----------------------------
The fact table contains millions of stop-level records.

DimStop centralizes descriptive stop attributes such as:

- Stop name
- Parent station
- Platform code
- Geographic coordinates
- Location type
- Wheelchair boarding information

Only StopIds actually used by wrk.Phase1TripStops are loaded.

This keeps the dimension compact and aligned with the implemented
Phase 1 business scope.

Parent station modeling
-----------------------
GTFS may represent physical platforms/stops separately from the
higher-level station entity.

By storing both the Stop and its ParentStation, reporting can be done at:

- platform / stop level
- station level

Example:
Several platform-level StopIds can roll up to Köln Hbf.
*/


IF OBJECT_ID('dw.DimStop', 'U') IS NOT NULL
    DROP TABLE dw.DimStop;
GO


CREATE TABLE dw.DimStop
(
    StopKey              INT IDENTITY(1,1) NOT NULL,

    StopId               NVARCHAR(255) NOT NULL,
    StopName             NVARCHAR(500) NULL,

    ParentStationId      NVARCHAR(255) NULL,
    ParentStationName    NVARCHAR(500) NULL,

    PlatformCode         NVARCHAR(100) NULL,

    Latitude             DECIMAL(9,6) NULL,
    Longitude            DECIMAL(9,6) NULL,

    LocationType         INT NULL,
    WheelchairBoarding   INT NULL,

    CONSTRAINT PK_dw_DimStop
        PRIMARY KEY CLUSTERED (StopKey),

    CONSTRAINT UQ_dw_DimStop_StopId
        UNIQUE (StopId)
);
GO


/*
Load Phase 1 stops
------------------
Only StopIds referenced by wrk.Phase1TripStops are loaded.

stg.Stops provides the stop-level attributes.

A self-join to stg.Stops resolves ParentStationName.
*/

INSERT INTO dw.DimStop
(
    StopId,
    StopName,
    ParentStationId,
    ParentStationName,
    PlatformCode,
    Latitude,
    Longitude,
    LocationType,
    WheelchairBoarding
)
SELECT DISTINCT
    s.StopId,
    s.StopName,
    s.ParentStation,
    ps.StopName AS ParentStationName,
    s.PlatformCode,
    s.StopLat,
    s.StopLon,
    s.LocationType,
    s.WheelchairBoarding
FROM wrk.Phase1TripStops p

INNER JOIN stg.Stops s
    ON p.StopId = s.StopId

LEFT JOIN stg.Stops ps
    ON s.ParentStation = ps.StopId;
GO


/*
Validation performed during implementation
------------------------------------------

Observed results:

StopCount               = 1,236
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0

This confirms that:

- 1,236 distinct stops are actually used by the Phase 1 dataset
- 918 of them can be rolled up to a parent station
- every loaded stop has a name
- every loaded stop has geographic coordinates
*/


SELECT
    COUNT(*) AS StopCount
FROM dw.DimStop;


SELECT
    COUNT(*) AS StopsWithParentStation
FROM dw.DimStop
WHERE ParentStationId IS NOT NULL;


SELECT
    COUNT(*) AS MissingStopNameCount
FROM dw.DimStop
WHERE StopName IS NULL;


SELECT
    COUNT(*) AS MissingCoordinatesCount
FROM dw.DimStop
WHERE Latitude IS NULL
   OR Longitude IS NULL;


SELECT TOP (30)
    StopKey,
    StopId,
    StopName,
    ParentStationId,
    ParentStationName,
    PlatformCode,
    Latitude,
    Longitude,
    LocationType,
    WheelchairBoarding
FROM dw.DimStop
ORDER BY
    COALESCE(ParentStationName, StopName),
    StopName;
