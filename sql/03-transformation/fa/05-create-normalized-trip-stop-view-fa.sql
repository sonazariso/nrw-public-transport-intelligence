USE NRWTransportDW;
GO

/*
هدف
---
نرمال‌سازی زمان‌های برنامه‌ریزی‌شده GTFS به DATETIME2 واقعی در SQL Server،
بدون تغییر یا از بین بردن مقدار خام زمان GTFS.

چرا Normalization لازم است؟
---------------------------
GTFS اجازه می‌دهد زمان سرویس از 24:00:00 عبور کند.

مثال‌های معتبر در GTFS:

24:00:00
25:10:00
26:35:00

این زمان‌ها نشان‌دهنده سرویسی هستند که بعد از نیمه‌شب ادامه پیدا می‌کند،
اما همچنان متعلق به ServiceDate روز قبل است.

SQL Server نوع TIME را برای مقادیری مثل 25:10:00 معتبر نمی‌داند.

بنابراین در لایه wrk:

- مقدار خام ScheduledArrival و ScheduledDeparture به صورت VARCHAR حفظ می‌شود
- مقدار تحلیلی DATETIME2 جداگانه محاسبه می‌شود
- DayOffset نیز محاسبه می‌شود تا مشخص باشد زمان چند روز از ServiceDate عبور کرده است

مثال
----
ServiceDate      = 2026-07-01
ScheduledArrival = 25:10:00

نتیجه نرمال‌شده:

ScheduledArrivalDateTime = 2026-07-02 01:10:00
ArrivalDayOffset         = 1

این طراحی باعث می‌شود هم GTFS semantics حفظ شود
و هم داده برای SQL Analytics و Power BI قابل استفاده باشد.
*/


CREATE OR ALTER VIEW wrk.vPhase1TripStopsNormalized
AS
SELECT
    TripStopKey,
    TripInstanceKey,
    ServiceDate,
    RouteId,
    TransportMode,
    StopId,
    StopSequence,

    ScheduledArrival,
    ScheduledDeparture,

    DATEADD
    (
        SECOND,
          CONVERT(INT, LEFT(ScheduledArrival, 2)) * 3600
        + CONVERT(INT, SUBSTRING(ScheduledArrival, 4, 2)) * 60
        + CONVERT(INT, RIGHT(ScheduledArrival, 2)),
        CAST(ServiceDate AS DATETIME2(0))
    ) AS ScheduledArrivalDateTime,

    DATEADD
    (
        SECOND,
          CONVERT(INT, LEFT(ScheduledDeparture, 2)) * 3600
        + CONVERT(INT, SUBSTRING(ScheduledDeparture, 4, 2)) * 60
        + CONVERT(INT, RIGHT(ScheduledDeparture, 2)),
        CAST(ServiceDate AS DATETIME2(0))
    ) AS ScheduledDepartureDateTime,

    CONVERT(INT, LEFT(ScheduledArrival, 2)) / 24
        AS ArrivalDayOffset,

    CONVERT(INT, LEFT(ScheduledDeparture, 2)) / 24
        AS DepartureDayOffset

FROM wrk.Phase1TripStops;
GO


/*
Validation واقعی انجام‌شده
-------------------------

AfterMidnightStopCount = 139,241

نمونه واقعی Validation:

ServiceDate              = 2026-07-01
ScheduledArrival         = 24:00:00
ScheduledArrivalDateTime = 2026-07-02 00:00:00
ArrivalDayOffset         = 1

این نتیجه تأیید کرد که زمان‌های بعد از نیمه‌شب GTFS
به درستی به DATETIME2 واقعی تبدیل می‌شوند.

نکته مهم:
ServiceDate تغییر نمی‌کند، چون از نظر GTFS این Trip همچنان
به Service Day اصلی تعلق دارد.

DATETIME2 فقط برای تحلیل زمانی ساخته می‌شود.
*/


SELECT TOP (30)
    ServiceDate,
    ScheduledArrival,
    ScheduledArrivalDateTime,
    ArrivalDayOffset,
    TransportMode,
    RouteId,
    StopId
FROM wrk.vPhase1TripStopsNormalized
WHERE ArrivalDayOffset > 0
ORDER BY
    ServiceDate,
    ScheduledArrivalDateTime;


SELECT
    COUNT(*) AS AfterMidnightStopCount
FROM wrk.vPhase1TripStopsNormalized
WHERE ArrivalDayOffset > 0
   OR DepartureDayOffset > 0;
