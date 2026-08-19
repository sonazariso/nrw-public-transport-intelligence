USE NRWTransportDW;
GO

CREATE TABLE stg.StopTimesImport
(
    TripId NVARCHAR(500) NULL,
    ArrivalTime VARCHAR(8) NULL,
    DepartureTime VARCHAR(8) NULL,
    StopId NVARCHAR(255) NULL,
    StopSequence INT NULL,
    StopHeadsign NVARCHAR(500) NULL,
    PickupType INT NULL,
    DropOffType INT NULL,
    ShapeDistTraveled DECIMAL(12,3) NULL
);
GO
