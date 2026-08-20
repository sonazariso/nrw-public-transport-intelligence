USE NRWTransportDW;
GO

/*
هدف
---
طبقه‌بندی Routeهای ریلی NRW برای Scope فاز اول پروژه:

- RE
- RB
- S-Bahn

و نگه‌داشتن Routeهای ریلی خارج از Scope با عنوان Other Rail.

چرا این Transformation لازم است؟
-------------------------------
هدف فاز اول پروژه تحلیل سرویس‌های ریلی منطقه‌ای NRW است.

Feed واقعی GTFS شامل چندین نوع حمل‌ونقل است و از Extended GTFS Route Types
استفاده می‌کند.

در Profiling اولیه مشخص شد که RouteType = 2 برای سرویس‌های ریلی موردنظر استفاده نشده است.

توزیع واقعی RouteTypeها در stg.Routes شامل موارد زیر بود:

0   = 586 Route
1   = 511 Route
3   = 4,647 Route
4   = 2 Route
106 = 52 Route
109 = 123 Route
405 = 28 Route

بررسی بیشتر نشان داد:

RouteType 106:
- 32 Route با پیشوند RE
- 20 Route با پیشوند RB

RouteType 109:
- 13 Route با پیشوند S و سازگار با S-Bahn
- 110 Route دیگر که با قانون نام‌گذاری S-Bahn در Scope فاز اول تطابق نداشتند

بنابراین Classification نهایی فقط بر اساس RouteType انجام نمی‌شود
و RouteShortName نیز در Business Rule استفاده می‌شود.

قوانین فاز اول
--------------
RouteType 106 + RE prefix -> RE
RouteType 106 + RB prefix -> RB
RouteType 109 + S prefix  -> S-Bahn

تمام Routeهای باقی‌مانده در 106/109 به صورت Other Rail نگه‌داری می‌شوند
و از Scope فاز اول خارج هستند.

این تصمیم Auditability را حفظ می‌کند:
Routeهای خارج‌شده حذف خاموش نمی‌شوند، بلکه مشخص است که دیده و عمداً Exclude شده‌اند.
*/


IF OBJECT_ID('wrk.RouteClassification', 'U') IS NOT NULL
    DROP TABLE wrk.RouteClassification;
GO

CREATE TABLE wrk.RouteClassification
(
    RouteId              NVARCHAR(255) NOT NULL,
    RouteShortName       NVARCHAR(100) NULL,
    RouteType            INT NOT NULL,
    TransportMode        NVARCHAR(50) NOT NULL,
    IsPhase1             BIT NOT NULL,
    ClassificationRule   NVARCHAR(255) NOT NULL,

    CONSTRAINT PK_wrk_RouteClassification
        PRIMARY KEY CLUSTERED (RouteId)
);
GO


INSERT INTO wrk.RouteClassification
(
    RouteId,
    RouteShortName,
    RouteType,
    TransportMode,
    IsPhase1,
    ClassificationRule
)
SELECT
    RouteId,
    RouteShortName,
    RouteType,

    CASE
        WHEN RouteType = 106
             AND RouteShortName LIKE 'RE%'
            THEN 'RE'

        WHEN RouteType = 106
             AND RouteShortName LIKE 'RB%'
            THEN 'RB'

        WHEN RouteType = 109
             AND RouteShortName LIKE 'S%'
            THEN 'S-Bahn'

        ELSE 'Other Rail'
    END AS TransportMode,

    CASE
        WHEN RouteType = 106
             AND
             (
                 RouteShortName LIKE 'RE%'
                 OR RouteShortName LIKE 'RB%'
             )
            THEN 1

        WHEN RouteType = 109
             AND RouteShortName LIKE 'S%'
            THEN 1

        ELSE 0
    END AS IsPhase1,

    CASE
        WHEN RouteType = 106
             AND RouteShortName LIKE 'RE%'
            THEN 'RouteType 106 + RE prefix'

        WHEN RouteType = 106
             AND RouteShortName LIKE 'RB%'
            THEN 'RouteType 106 + RB prefix'

        WHEN RouteType = 109
             AND RouteShortName LIKE 'S%'
            THEN 'RouteType 109 + S prefix'

        ELSE 'Excluded from Phase 1 after profiling'
    END AS ClassificationRule

FROM stg.Routes
WHERE RouteType IN (106, 109);
GO


/*
Validation واقعی انجام‌شده
-------------------------

نتایج مشاهده‌شده:

RB          | IsPhase1 = 1 | 20 Route
RE          | IsPhase1 = 1 | 32 Route
S-Bahn      | IsPhase1 = 1 | 13 Route
Other Rail  | IsPhase1 = 0 | 110 Route

Total classified routes = 175
Phase 1 routes          = 65

110 Route خارج‌شده از RouteType 109 جداگانه بررسی شدند.

در Profiling مشاهده شد که این Routeها عمدتاً:
- AgencyName = VRR
- RouteShortName عددی

داشتند و با الگوی نام‌گذاری S-Bahn در Scope فاز اول مطابقت نداشتند.
*/


SELECT
    TransportMode,
    IsPhase1,
    COUNT(*) AS RouteCount
FROM wrk.RouteClassification
GROUP BY
    TransportMode,
    IsPhase1
ORDER BY
    IsPhase1 DESC,
    TransportMode;


SELECT
    COUNT(*) AS Phase1RouteCount
FROM wrk.RouteClassification
WHERE IsPhase1 = 1;
