USE NRWTransportDW;
GO

/*
هدف
---
ایجاد Fact Table نهایی فاز اول در Grain سطح Trip-Stop.

Grain
-----
هر ردیف = یک TripInstance برنامه‌ریزی‌شده در یک StopSequence مشخص.

این Grain قبلاً در wrk.Phase1TripStops بررسی و تأیید شده بود
و در Fact Table نهایی نیز بدون تغییر حفظ می‌شود.

چرا این Fact Table لازم است؟
---------------------------
لایه wrk هنوز Business Identifierهایی مثل RouteId و StopId را نگه می‌دارد.

در Warehouse، Fact Table به‌جای تکرار این شناسه‌های متنی در میلیون‌ها ردیف،
از Surrogate Keyهای عددی Dimensionها استفاده می‌کند:

- dw.DimDate
- dw.DimRoute
- dw.DimStop

این جدول هسته مرکزی Star Schema است و مدل را برای Queryهای تحلیلی
و Power BI آماده می‌کند.

همچنین زمان‌های نرمال‌شده Arrival/Departure و GTFS DayOffset
برای سرویس‌هایی که از نیمه‌شب عبور می‌کنند در Fact نگه‌داری می‌شوند.
*/


IF OBJECT_ID('dw.FactTripStop', 'U') IS NOT NULL
    DROP TABLE dw.FactTripStop;
GO


CREATE TABLE dw.FactTripStop
(
    FactTripStopKey              BIGINT IDENTITY(1,1) NOT NULL,

    DateKey                      INT NOT NULL,
    RouteKey                     INT NOT NULL,
    StopKey                      INT NOT NULL,

    TripInstanceKey              BIGINT NOT NULL,
    StopSequence                 INT NOT NULL,

    ScheduledArrivalDateTime     DATETIME2(0) NULL,
    ScheduledDepartureDateTime   DATETIME2(0) NULL,

    ArrivalDayOffset             TINYINT NULL,
    DepartureDayOffset           TINYINT NULL,

    CONSTRAINT PK_dw_FactTripStop
        PRIMARY KEY CLUSTERED (FactTripStopKey)
);
GO


/*
چرا Foreign Keyها قبل از Load ساخته نشدند؟
-----------------------------------------
Fact Table بیش از 8 میلیون ردیف دارد.

در Load اولیه، Constraintهای فیزیکی Foreign Key عمداً ساخته نشدند
تا SQL Server مجبور نباشد برای هر ردیف Referential Integrity را
در زمان Insert بررسی کند.

ارتباط‌های منطقی عبارت‌اند از:

DateKey  -> dw.DimDate(DateKey)
RouteKey -> dw.DimRoute(RouteKey)
StopKey  -> dw.DimStop(StopKey)

بعد از Load و Validation کامل، این Constraintها می‌توانند
در مرحله Hardening به‌صورت جداگانه اضافه شوند.
*/


INSERT INTO dw.FactTripStop
(
    DateKey,
    RouteKey,
    StopKey,
    TripInstanceKey,
    StopSequence,
    ScheduledArrivalDateTime,
    ScheduledDepartureDateTime,
    ArrivalDayOffset,
    DepartureDayOffset
)
SELECT
    d.DateKey,
    r.RouteKey,
    s.StopKey,
    p.TripInstanceKey,
    p.StopSequence,
    p.ScheduledArrivalDateTime,
    p.ScheduledDepartureDateTime,
    p.ArrivalDayOffset,
    p.DepartureDayOffset
FROM wrk.vPhase1TripStopsNormalized p

INNER JOIN dw.DimDate d
    ON p.ServiceDate = d.FullDate

INNER JOIN dw.DimRoute r
    ON p.RouteId = r.RouteId

INNER JOIN dw.DimStop s
    ON p.StopId = s.StopId;
GO


/*
Validation واقعی انجام‌شده
-------------------------

نتیجه مشاهده‌شده:

FactRowCount = 8,029,550

مقایسه Work Layer و Fact:

wrk.Phase1TripStops = 8,029,550
dw.FactTripStop     = 8,029,550

برابر بودن دقیق تعداد ردیف‌ها تأیید می‌کند که در Join به:

- DimDate
- DimRoute
- DimStop

هیچ رکورد Phase 1 از دست نرفته است.

Grain Validation
----------------
ترکیب زیر بررسی شد:

TripInstanceKey + StopSequence

نتیجه:
Duplicate = صفر

بنابراین Grain موردنظر Trip-Stop در Fact Table نهایی نیز کاملاً حفظ شده است.
*/


SELECT
    COUNT(*) AS FactRowCount
FROM dw.FactTripStop;


SELECT
    (SELECT COUNT(*) FROM wrk.Phase1TripStops) AS WorkRowCount,
    (SELECT COUNT(*) FROM dw.FactTripStop) AS FactRowCount;


SELECT
    TripInstanceKey,
    StopSequence,
    COUNT(*) AS DuplicateCount
FROM dw.FactTripStop
GROUP BY
    TripInstanceKey,
    StopSequence
HAVING COUNT(*) > 1;
