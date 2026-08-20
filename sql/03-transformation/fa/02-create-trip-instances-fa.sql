USE NRWTransportDW;
GO

/*
هدف
---
ایجاد یک Trip Instance برنامه‌ریزی‌شده برای هر ترکیب TripId + ServiceDate.

Grain
-----
هر ردیف = یک GTFS Trip که در یک تاریخ مشخص اجرا می‌شود.

چرا این Transformation لازم است؟
-------------------------------
جدول GTFS trips شامل تعریف‌های تکرارشونده Trip است و هر Trip به یک ServiceId وصل می‌شود.

جدول wrk.ServiceDates مشخص می‌کند هر ServiceId دقیقاً در چه تاریخ‌هایی فعال است.

با Join کردن stg.Trips به wrk.ServiceDates، هر Trip Template به یک اجرای برنامه‌ریزی‌شده
در یک تاریخ مشخص تبدیل می‌شود.

مثال
----
TripId = T100
ServiceId = Special

اگر Special در این تاریخ‌ها فعال باشد:
2026-07-01
2026-07-02

خروجی می‌شود:

T100 + 2026-07-01
T100 + 2026-07-02
*/


/*
یادداشت طراحی: Profiling طول TripId
-----------------------------------
طراحی اولیه این بود:

TripId NVARCHAR(500)
PRIMARY KEY (TripId, ServiceDate)

SQL Server هشدار داد که کلید clustered index ممکن است از محدودیت طول مجاز عبور کند،
چون NVARCHAR(500) به‌تنهایی ممکن است تا حدود 1000 byte مصرف کند و ServiceDate هم
به کلید اضافه می‌شود.

برای جلوگیری از طراحی بیش‌ازحد بزرگ، طول واقعی TripId در داده منبع بررسی شد.

نتایج واقعی:
- Minimum Length = 19
- Maximum Length = 66
- Average Length ≈ 44.41

بنابراین در لایه wrk، TripId به NVARCHAR(100) کاهش داده شد.
این مقدار برای طول واقعی داده حاشیه امن کافی دارد و Indexها را نیز کوچک‌تر و کارآمدتر می‌کند.

همچنین به‌جای Composite Primary Key، یک Surrogate Key از نوع BIGINT ایجاد شد.
ترکیب TripId + ServiceDate همچنان به‌عنوان Business Key یکتا حفظ می‌شود.
*/


IF OBJECT_ID('wrk.TripInstances', 'U') IS NOT NULL
    DROP TABLE wrk.TripInstances;
GO

CREATE TABLE wrk.TripInstances
(
    TripInstanceKey BIGINT IDENTITY(1,1) NOT NULL,

    TripId          NVARCHAR(100) NOT NULL,
    ServiceDate     DATE NOT NULL,
    RouteId         NVARCHAR(255) NOT NULL,
    ServiceId       NVARCHAR(255) NOT NULL,
    DirectionId     INT NULL,
    TripHeadsign    NVARCHAR(500) NULL,

    CONSTRAINT PK_wrk_TripInstances
        PRIMARY KEY CLUSTERED (TripInstanceKey)
);
GO


/*
Business Key
------------
یک TripId می‌تواند در چند تاریخ مختلف اجرا شود،
اما ترکیب TripId + ServiceDate نباید بیش از یک بار وجود داشته باشد.
*/

CREATE UNIQUE INDEX UX_wrk_TripInstances_TripId_ServiceDate
ON wrk.TripInstances
(
    TripId,
    ServiceDate
);
GO


/*
Load Trip Instances
-------------------
GTFS Tripهای قابل استفاده مجدد به تاریخ‌های واقعی سرویس وصل می‌شوند.
*/

INSERT INTO wrk.TripInstances
(
    TripId,
    ServiceDate,
    RouteId,
    ServiceId,
    DirectionId,
    TripHeadsign
)
SELECT
    t.TripId,
    sd.ServiceDate,
    t.RouteId,
    t.ServiceId,
    t.DirectionId,
    t.TripHeadsign
FROM stg.Trips t
INNER JOIN wrk.ServiceDates sd
    ON t.ServiceId = sd.ServiceId;
GO


/*
Performance Index
-----------------
در مراحل بعدی لازم است:
- بر اساس RouteId فیلتر کنیم
- و با StopTimes بر اساس TripId Join انجام دهیم

این Index برای سریع‌تر شدن Transformationهای بعدی ساخته شد.
*/

CREATE INDEX IX_wrk_TripInstances_RouteId_TripId
ON wrk.TripInstances
(
    RouteId,
    TripId
)
INCLUDE
(
    TripInstanceKey,
    ServiceDate
);
GO


/*
Validation واقعی انجام‌شده
-------------------------

نتایج مشاهده‌شده:

TripInstanceCount = 26,356,341

بازه تاریخ:
FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-31
ServiceDayCount  = 184

Unique Index روی TripId + ServiceDate بدون خطا ساخته شد.
*/


SELECT
    COUNT(*) AS TripInstanceCount
FROM wrk.TripInstances;


SELECT
    MIN(ServiceDate) AS FirstServiceDate,
    MAX(ServiceDate) AS LastServiceDate,
    COUNT(DISTINCT ServiceDate) AS ServiceDayCount
FROM wrk.TripInstances;


SELECT TOP (20)
    TripInstanceKey,
    TripId,
    ServiceDate,
    RouteId,
    ServiceId
FROM wrk.TripInstances
ORDER BY
    ServiceDate,
    TripInstanceKey;
