USE NRWTransportDW;
GO

CREATE TABLE stg.Routes
(
    RouteId NVARCHAR(255) NOT NULL,
    AgencyId NVARCHAR(100) NULL,
    RouteShortName NVARCHAR(100) NULL,
    RouteLongName NVARCHAR(500) NULL,
    RouteType INT NULL,
    RouteColor NVARCHAR(20) NULL,
    RouteTextColor NVARCHAR(20) NULL,
    NvbwDlid NVARCHAR(255) NULL,
    LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_Routes_LoadDateTime DEFAULT SYSDATETIME()
);
GO

CREATE TABLE stg.Agency
(
    AgencyId NVARCHAR(100) NOT NULL,
    AgencyName NVARCHAR(255) NULL,
    AgencyUrl NVARCHAR(500) NULL,
    AgencyTimezone NVARCHAR(100) NULL,
    AgencyLang NVARCHAR(20) NULL,
    AgencyFareUrl NVARCHAR(500) NULL,
    AgencyEmail NVARCHAR(255) NULL,
    LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_Agency_LoadDateTime DEFAULT SYSDATETIME()
);
GO

CREATE TABLE stg.Trips
(
    RouteId NVARCHAR(255) NOT NULL,
    ServiceId NVARCHAR(255) NOT NULL,
    TripId NVARCHAR(500) NOT NULL,
    ShapeId NVARCHAR(500) NULL,
    TripHeadsign NVARCHAR(500) NULL,
    TripShortName NVARCHAR(100) NULL,
    DirectionId INT NULL,
    WheelchairAccessible INT NULL,
    LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_Trips_LoadDateTime DEFAULT SYSDATETIME()
);
GO

CREATE TABLE stg.Stops
(
    StopId NVARCHAR(255) NOT NULL,
    StopCode NVARCHAR(100) NULL,
    StopName NVARCHAR(500) NULL,
    StopLat DECIMAL(9,6) NULL,
    StopLon DECIMAL(9,6) NULL,
    StopUrl NVARCHAR(500) NULL,
    LocationType INT NULL,
    ParentStation NVARCHAR(255) NULL,
    WheelchairBoarding INT NULL,
    PlatformCode NVARCHAR(100) NULL,
    NvbwHstDhid NVARCHAR(255) NULL,
    LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_Stops_LoadDateTime DEFAULT SYSDATETIME()
);
GO

CREATE TABLE stg.StopTimes
(
    TripId NVARCHAR(500) NOT NULL,
    ArrivalTime VARCHAR(8) NULL,
    DepartureTime VARCHAR(8) NULL,
    StopId NVARCHAR(255) NOT NULL,
    StopSequence INT NOT NULL,
    StopHeadsign NVARCHAR(500) NULL,
    PickupType INT NULL,
    DropOffType INT NULL,
    ShapeDistTraveled DECIMAL(12,3) NULL,
    LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_StopTimes_LoadDateTime DEFAULT SYSDATETIME()
);
GO

CREATE TABLE stg.Calendar
(
    ServiceId NVARCHAR(255) NOT NULL,
    Monday BIT NOT NULL,
    Tuesday BIT NOT NULL,
    Wednesday BIT NOT NULL,
    Thursday BIT NOT NULL,
    Friday BIT NOT NULL,
    Saturday BIT NOT NULL,
    Sunday BIT NOT NULL,
    StartDate CHAR(8) NOT NULL,
    EndDate CHAR(8) NOT NULL,
    LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_Calendar_LoadDateTime DEFAULT SYSDATETIME()
);
GO

CREATE TABLE stg.CalendarDates
(
    ServiceId NVARCHAR(255) NOT NULL,
    ServiceDate CHAR(8) NOT NULL,
    ExceptionType INT NOT NULL,
    LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_CalendarDates_LoadDateTime DEFAULT SYSDATETIME()
);
GO

CREATE TABLE stg.FeedInfo
(
    FeedPublisherName NVARCHAR(255) NULL,
    FeedPublisherUrl NVARCHAR(500) NULL,
    FeedLang NVARCHAR(20) NULL,
    DefaultLang NVARCHAR(20) NULL,
    FeedStartDate CHAR(8) NULL,
    FeedEndDate CHAR(8) NULL,
    FeedVersion NVARCHAR(100) NULL,
    FeedContactEmail NVARCHAR(255) NULL,
    FeedContactUrl NVARCHAR(500) NULL,
    LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_FeedInfo_LoadDateTime DEFAULT SYSDATETIME()
);
GO
