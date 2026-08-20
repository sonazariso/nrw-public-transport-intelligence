USE NRWTransportDW;
GO

/*
هدف
---
ایجاد فهرست صریح تاریخ‌های فعال سرویس از دو جدول staging مربوط به GTFS:

- stg.Calendar
- stg.CalendarDates

Grain
-----
هر ردیف = یک ServiceId در یک ServiceDate مشخص

چرا این Transformation لازم است؟
-------------------------------
در GTFS، جدول trips مستقیماً تاریخ واقعی اجرا را نگه نمی‌دارد.
هر Trip به یک ServiceId متصل است.

جدول calendar الگوی هفتگی سرویس را مشخص می‌کند و
calendar_dates استثناهای تقویمی را نگه می‌دارد.

در نتیجه، این مرحله هر ServiceId را به تاریخ‌های واقعی و قابل استفاده
برای Join با Tripها تبدیل می‌کند.

GTFS calendar_dates exception_type:
1 = سرویس اضافه شده
2 = سرویس حذف شده
*/

IF OBJECT_ID('wrk.ServiceDates', 'U') IS NOT NULL
    DROP TABLE wrk.ServiceDates;
GO

CREATE TABLE wrk.ServiceDates
(
    ServiceId   NVARCHAR(255) NOT NULL,
    ServiceDate DATE NOT NULL,

    CONSTRAINT PK_wrk_ServiceDates
        PRIMARY KEY CLUSTERED
        (
            ServiceId,
            ServiceDate
        )
);
GO

;WITH DateSeries AS
(
    SELECT
        ServiceId,
        StartDate AS ServiceDate,
        EndDate,
        Monday,
        Tuesday,
        Wednesday,
        Thursday,
        Friday,
        Saturday,
        Sunday
    FROM stg.Calendar

    UNION ALL

    SELECT
        ServiceId,
        DATEADD(DAY, 1, ServiceDate),
        EndDate,
        Monday,
        Tuesday,
        Wednesday,
        Thursday,
        Friday,
        Saturday,
        Sunday
    FROM DateSeries
    WHERE ServiceDate < EndDate
),
CalendarServiceDates AS
(
    SELECT
        ServiceId,
        ServiceDate
    FROM DateSeries
    WHERE
           (DATENAME(WEEKDAY, ServiceDate) = 'Monday'    AND Monday    = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Tuesday'   AND Tuesday   = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Wednesday' AND Wednesday = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Thursday'  AND Thursday  = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Friday'    AND Friday    = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Saturday'  AND Saturday  = 1)
        OR (DATENAME(WEEKDAY, ServiceDate) = 'Sunday'    AND Sunday    = 1)
),
AddedServiceDates AS
(
    SELECT
        ServiceId,
        CONVERT(DATE, ServiceDate, 112) AS ServiceDate
    FROM stg.CalendarDates
    WHERE ExceptionType = 1
),
Combined AS
(
    SELECT
        ServiceId,
        ServiceDate
    FROM CalendarServiceDates

    UNION

    SELECT
        ServiceId,
        ServiceDate
    FROM AddedServiceDates
),
RemovedServiceDates AS
(
    SELECT
        ServiceId,
        CONVERT(DATE, ServiceDate, 112) AS ServiceDate
    FROM stg.CalendarDates
    WHERE ExceptionType = 2
)
INSERT INTO wrk.ServiceDates
(
    ServiceId,
    ServiceDate
)
SELECT
    c.ServiceId,
    c.ServiceDate
FROM Combined c
LEFT JOIN RemovedServiceDates r
    ON  c.ServiceId   = r.ServiceId
    AND c.ServiceDate = r.ServiceDate
WHERE r.ServiceId IS NULL
OPTION (MAXRECURSION 0);
GO


/*
Validation واقعی انجام‌شده
-------------------------
نتایج مشاهده‌شده:

ServiceDateCount      = 406,747
DistinctServiceCount  = 9,430
FirstServiceDate      = 2026-07-01
LastServiceDate       = 2026-12-31

بررسی‌های تکمیلی:
- Duplicate روی ServiceId + ServiceDate = صفر
- تاریخ‌های ExceptionType = 2 که اشتباهی باقی مانده باشند = صفر
*/

SELECT
    COUNT(*) AS ServiceDateCount,
    COUNT(DISTINCT ServiceId) AS DistinctServiceCount,
    MIN(ServiceDate) AS FirstServiceDate,
    MAX(ServiceDate) AS LastServiceDate
FROM wrk.ServiceDates;

SELECT
    ServiceId,
    ServiceDate,
    COUNT(*) AS DuplicateCount
FROM wrk.ServiceDates
GROUP BY
    ServiceId,
    ServiceDate
HAVING COUNT(*) > 1;

SELECT
    COUNT(*) AS RemovedServicesStillPresent
FROM wrk.ServiceDates sd
INNER JOIN stg.CalendarDates cd
    ON sd.ServiceId = cd.ServiceId
    AND sd.ServiceDate = CONVERT(DATE, cd.ServiceDate, 112)
WHERE cd.ExceptionType = 2;
