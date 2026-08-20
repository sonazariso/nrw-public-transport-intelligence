USE NRWTransportDW;
GO

/*
هدف
---
ایجاد یک View تحلیلی و Business-Friendly روی Star Schema فاز اول.

چرا این View لازم است؟
---------------------
Fact Table عمداً فشرده طراحی شده و عمدتاً Surrogate Key نگه می‌دارد:

- DateKey
- RouteKey
- StopKey

برای Validation، تحلیل SQL و Power BI آینده، نیاز داریم ویژگی‌های قابل فهم
تجاری را مستقیم ببینیم، مانند:

- ServiceDate
- RouteShortName
- TransportMode
- OperatorName
- StopName
- ParentStationName
- Scheduled timestamps

این View، Fact Table را به Dimensionها Join می‌کند و اطلاعات توصیفی را
بدون کپی کردن داده Warehouse در اختیار تحلیلگر قرار می‌دهد.

نکته مهم
--------
این View فقط Scheduled Service را نمایش می‌دهد.

این داده‌ها به معنی موارد زیر نیستند:

- Actual operation
- Delay
- Cancellation
- Passenger count
*/


CREATE OR ALTER VIEW dw.vTripStopAnalytics
AS
SELECT
    f.FactTripStopKey,
    f.TripInstanceKey,
    f.StopSequence,

    d.FullDate AS ServiceDate,
    d.DayName,
    d.MonthName,
    d.WeekNumber,
    d.IsWeekend,

    r.RouteKey,
    r.RouteId,
    r.RouteShortName,
    r.TransportMode,
    r.OperatorName,

    s.StopKey,
    s.StopId,
    s.StopName,
    s.ParentStationName,
    s.PlatformCode,
    s.Latitude,
    s.Longitude,

    f.ScheduledArrivalDateTime,
    f.ScheduledDepartureDateTime,
    f.ArrivalDayOffset,
    f.DepartureDayOffset

FROM dw.FactTripStop f

INNER JOIN dw.DimDate d
    ON f.DateKey = d.DateKey

INNER JOIN dw.DimRoute r
    ON f.RouteKey = r.RouteKey

INNER JOIN dw.DimStop s
    ON f.StopKey = s.StopKey;
GO


/*
Business Validation Queryهای واقعی اجراشده
-----------------------------------------

1. حجم Scheduled Stop به تفکیک TransportMode

نتایج مشاهده‌شده:

S-Bahn = 3,748,784
RE     = 2,536,487
RB     = 1,744,279
*/

SELECT
    TransportMode,
    COUNT(*) AS ScheduledStopCount
FROM dw.vTripStopAnalytics
GROUP BY TransportMode
ORDER BY ScheduledStopCount DESC;


/*
2. ده Route پرتراکم بر اساس Scheduled Stop Count

نمونه نتایج مشاهده‌شده در بین Routeهای بالای جدول:

S1  = 611,744
S11 = 593,650
S6  = 507,587

نکته:
این اعداد تعداد ردیف‌های Scheduled Trip-Stop هستند.

این اعداد به معنی Passenger Count یا تعداد Train Movement یکتا نیستند.
*/

SELECT TOP (10)
    RouteShortName,
    TransportMode,
    OperatorName,
    COUNT(*) AS ScheduledStopCount
FROM dw.vTripStopAnalytics
GROUP BY
    RouteShortName,
    TransportMode,
    OperatorName
ORDER BY ScheduledStopCount DESC;


/*
3. ده Station پرتراکم بر اساس Scheduled Stop Count

هرجا ParentStationName موجود باشد، از آن استفاده می‌شود تا StopIdهای مختلف
Platformها در سطح Station اصلی تجمیع شوند.

نمونه نتایج مشاهده‌شده:

Düsseldorf Hbf       = 162,531
Dortmund Hbf         = 139,004
Essen Hauptbahnhof   = 137,343
Köln Hbf             = 85,188

این اعداد فقط Scheduled Stop Event Count هستند.
*/

SELECT TOP (10)
    COALESCE(ParentStationName, StopName) AS StationName,
    COUNT(*) AS ScheduledStopCount
FROM dw.vTripStopAnalytics
GROUP BY
    COALESCE(ParentStationName, StopName)
ORDER BY ScheduledStopCount DESC;
