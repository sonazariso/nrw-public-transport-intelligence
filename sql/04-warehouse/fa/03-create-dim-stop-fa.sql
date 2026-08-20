USE NRWTransportDW;
GO

/*
هدف
---
ایجاد Dimension ایستگاه برای Data Warehouse فاز اول پروژه.

Grain
-----
هر ردیف = یک GTFS StopId که واقعاً در دیتاست Phase 1 Trip-Stop استفاده شده است.

چرا این Dimension لازم است؟
---------------------------
Fact Table شامل میلیون‌ها رکورد در سطح Stop است.

DimStop ویژگی‌های توصیفی ایستگاه را به‌صورت متمرکز نگه می‌دارد، از جمله:

- نام Stop
- Parent Station
- Platform Code
- مختصات جغرافیایی
- Location Type
- اطلاعات Wheelchair Boarding

فقط StopIdهایی وارد Dimension می‌شوند که واقعاً در
wrk.Phase1TripStops وجود دارند.

این تصمیم باعث می‌شود Dimension کوچک، کاربردی و دقیقاً منطبق با Scope واقعی
Phase 1 باقی بماند.

مدل‌سازی Parent Station
-----------------------
در GTFS ممکن است هر Platform یا Stop فیزیکی یک StopId جداگانه داشته باشد،
در حالی که چند Stop همگی متعلق به یک Station اصلی باشند.

با نگه‌داری هم‌زمان Stop و ParentStation می‌توان گزارش‌ها را در دو سطح ساخت:

- Platform / Stop
- Station

مثال:
چند StopId مربوط به Platformهای مختلف می‌توانند در تحلیل نهایی
زیر Köln Hbf تجمیع شوند.
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
Load Phase 1 Stops
------------------
فقط StopIdهایی Load می‌شوند که در wrk.Phase1TripStops استفاده شده‌اند.

stg.Stops ویژگی‌های Stop را فراهم می‌کند.

با Self Join روی stg.Stops، نام Parent Station نیز Resolve می‌شود.
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
Validation واقعی انجام‌شده
-------------------------

نتایج مشاهده‌شده:

StopCount               = 1,236
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0

این نتایج تأیید می‌کنند که:

- 1,236 Stop متمایز واقعاً در دیتاست Phase 1 استفاده شده‌اند
- 918 Stop دارای Parent Station هستند و می‌توانند در سطح Station تجمیع شوند
- هیچ Stop بدون نام وجود ندارد
- هیچ Stop بدون مختصات جغرافیایی وجود ندارد
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
