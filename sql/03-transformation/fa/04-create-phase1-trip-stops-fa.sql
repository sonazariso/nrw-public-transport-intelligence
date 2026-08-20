USE NRWTransportDW;
GO

/*
هدف
---
ایجاد دیتاست کاری Phase 1 در سطح Trip-Stop برای سرویس‌های ریلی منطقه‌ای NRW.

Business Scope
--------------
فاز اول فقط شامل این سه نوع سرویس است:

- RE
- RB
- S-Bahn

داده کامل GTFS شامل Bus، Tram، Metro/Subway و سایر انواع حمل‌ونقل نیز هست،
اما این موارد در Scope فعلی پروژه قرار ندارند.

Grain
-----
هر ردیف = یک TripInstance در یک StopSequence مشخص.

این اولین دیتاست کاری است که دقیقاً با Grain موردنظر Fact Table نهایی هماهنگ است.

چرا Scope Reduction لازم بود؟
----------------------------
قبل از Materialize کردن دیتاست Trip-Stop، حجم تقریبی داده بررسی شد.

Estimated full GTFS fact volume:
602,397,175 rows

Estimated RouteType 106/109 rail-like volume:
12,481,010 rows

Estimated final Phase 1 volume after applying validated
RE/RB/S-Bahn classification:
8,029,550 rows

بنابراین تصمیم گرفته شد در فاز اول کل شبکه چندوجهی GTFS در لایه wrk/dw
Materialize نشود.

نکته مهم:
تمام داده خام در لایه stg حفظ شده است.
Scope تجاری فقط در لایه‌های wrk و dw اعمال می‌شود.

این طراحی باعث می‌شود:
- Source Data کامل حفظ شود
- Scope پروژه شفاف باشد
- حجم پردازش کنترل شود
- توسعه فازهای بعدی برای Bus/Tram/Metro همچنان ممکن باشد
*/


IF OBJECT_ID('wrk.Phase1TripStops', 'U') IS NOT NULL
    DROP TABLE wrk.Phase1TripStops;
GO

CREATE TABLE wrk.Phase1TripStops
(
    TripStopKey          BIGINT IDENTITY(1,1) NOT NULL,
    TripInstanceKey      BIGINT NOT NULL,

    ServiceDate          DATE NOT NULL,
    RouteId              NVARCHAR(255) NOT NULL,
    TransportMode        NVARCHAR(50) NOT NULL,

    StopId               NVARCHAR(255) NOT NULL,
    StopSequence         INT NOT NULL,

    ScheduledArrival     VARCHAR(8) NULL,
    ScheduledDeparture   VARCHAR(8) NULL,

    CONSTRAINT PK_wrk_Phase1TripStops
        PRIMARY KEY CLUSTERED (TripStopKey)
);
GO


/*
Load Phase 1 Trip-Stop Data
---------------------------
سه منبع اصلی در این مرحله Join می‌شوند:

1. wrk.TripInstances
   برای داشتن Trip واقعی در یک ServiceDate مشخص

2. wrk.RouteClassification
   برای محدود کردن داده به Routeهای معتبر Phase 1

3. stg.StopTimes
   برای اضافه کردن Stop، StopSequence و زمان‌های برنامه‌ریزی‌شده

فقط Routeهایی وارد می‌شوند که:
IsPhase1 = 1
*/

INSERT INTO wrk.Phase1TripStops
(
    TripInstanceKey,
    ServiceDate,
    RouteId,
    TransportMode,
    StopId,
    StopSequence,
    ScheduledArrival,
    ScheduledDeparture
)
SELECT
    ti.TripInstanceKey,
    ti.ServiceDate,
    ti.RouteId,
    rc.TransportMode,
    st.StopId,
    st.StopSequence,
    st.ArrivalTime,
    st.DepartureTime
FROM wrk.TripInstances ti

INNER JOIN wrk.RouteClassification rc
    ON ti.RouteId = rc.RouteId
   AND rc.IsPhase1 = 1

INNER JOIN stg.StopTimes st
    ON ti.TripId = st.TripId;
GO


/*
Validation واقعی انجام‌شده
-------------------------

Total Phase 1 Trip-Stop rows:
8,029,550

Breakdown by TransportMode:

RB      = 1,744,279
RE      = 2,536,487
S-Bahn  = 3,748,784

جمع:
8,029,550

Grain Validation
----------------
ترکیب زیر بررسی شد:

TripInstanceKey + StopSequence

نتیجه:
Duplicate = صفر

بنابراین هر Trip Instance در هر Stop Sequence فقط یک بار وجود دارد.

Service Date Coverage
---------------------
FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-12
ServiceDayCount  = 165

این بازه از wrk.ServiceDates کوتاه‌تر است.

wrk.ServiceDates کل GTFS feed را پوشش می‌دهد و تا 2026-12-31 ادامه دارد،
اما wrk.Phase1TripStops فقط 65 Route انتخاب‌شده در Phase 1 را شامل می‌شود.

بنابراین این اختلاف الزاماً Data Quality Error نیست؛
بلکه نتیجه Scope Filtering است.
*/


SELECT
    COUNT(*) AS Phase1TripStopCount
FROM wrk.Phase1TripStops;


SELECT
    TransportMode,
    COUNT(*) AS TripStopCount
FROM wrk.Phase1TripStops
GROUP BY TransportMode
ORDER BY TransportMode;


SELECT
    TripInstanceKey,
    StopSequence,
    COUNT(*) AS DuplicateCount
FROM wrk.Phase1TripStops
GROUP BY
    TripInstanceKey,
    StopSequence
HAVING COUNT(*) > 1;


SELECT
    MIN(ServiceDate) AS FirstServiceDate,
    MAX(ServiceDate) AS LastServiceDate,
    COUNT(DISTINCT ServiceDate) AS ServiceDayCount
FROM wrk.Phase1TripStops;
