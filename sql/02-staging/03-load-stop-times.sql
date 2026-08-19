USE NRWTransportDW;
GO

TRUNCATE TABLE stg.StopTimesImport;
GO

BULK INSERT stg.StopTimesImport
FROM 'C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit\stop_times.txt'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK,
    KEEPNULLS
);
GO

TRUNCATE TABLE stg.StopTimes;
GO

INSERT INTO stg.StopTimes
(
    TripId,
    ArrivalTime,
    DepartureTime,
    StopId,
    StopSequence,
    StopHeadsign,
    PickupType,
    DropOffType,
    ShapeDistTraveled
)
SELECT
    TripId,
    ArrivalTime,
    DepartureTime,
    StopId,
    StopSequence,
    StopHeadsign,
    PickupType,
    DropOffType,
    ShapeDistTraveled
FROM stg.StopTimesImport;
GO

SELECT COUNT(*) AS StopTimesCount
FROM stg.StopTimes;
GO
