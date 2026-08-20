USE NRWTransportDW;
GO

/*
هدف
---
ایجاد Dimension مسیر برای Data Warehouse فاز اول پروژه.

Grain
-----
هر ردیف = یک RouteId متعلق به Scope فاز اول.

چرا این Dimension لازم است؟
---------------------------
Fact Table نباید ویژگی‌های توصیفی Route را در میلیون‌ها ردیف تکرار کند.

DimRoute اطلاعات Route را یک‌بار و به‌صورت متمرکز نگه می‌دارد، از جمله:

- شناسه Route
- نام کوتاه و بلند Route
- نوع سرویس حمل‌ونقل
- Operator / Agency
- RouteType اصلی GTFS

فقط Routeهایی وارد این Dimension می‌شوند که قبلاً در
wrk.RouteClassification به‌صورت معتبر در Phase 1 طبقه‌بندی شده‌اند:

- RE
- RB
- S-Bahn

به این ترتیب Warehouse دقیقاً با Scope تجاری تأییدشده هماهنگ می‌ماند،
در حالی که داده کامل منبع همچنان در لایه stg حفظ شده است.
*/


IF OBJECT_ID('dw.DimRoute', 'U') IS NOT NULL
    DROP TABLE dw.DimRoute;
GO


CREATE TABLE dw.DimRoute
(
    RouteKey          INT IDENTITY(1,1) NOT NULL,

    RouteId           NVARCHAR(255) NOT NULL,
    RouteShortName    NVARCHAR(100) NULL,
    RouteLongName     NVARCHAR(500) NULL,

    TransportMode     NVARCHAR(50) NOT NULL,

    AgencyId          NVARCHAR(100) NULL,
    OperatorName      NVARCHAR(255) NULL,

    SourceRouteType   INT NOT NULL,

    CONSTRAINT PK_dw_DimRoute
        PRIMARY KEY CLUSTERED (RouteKey),

    CONSTRAINT UQ_dw_DimRoute_RouteId
        UNIQUE (RouteId)
);
GO


/*
Load Phase 1 Routes
-------------------
wrk.RouteClassification شامل Classification تجاری و تأییدشده Routeها است.

stg.Routes ویژگی‌های اصلی GTFS Route را فراهم می‌کند.

stg.Agency نام Operator را فراهم می‌کند.
*/

INSERT INTO dw.DimRoute
(
    RouteId,
    RouteShortName,
    RouteLongName,
    TransportMode,
    AgencyId,
    OperatorName,
    SourceRouteType
)
SELECT
    r.RouteId,
    r.RouteShortName,
    r.RouteLongName,
    rc.TransportMode,
    r.AgencyId,
    a.AgencyName,
    r.RouteType
FROM stg.Routes r

INNER JOIN wrk.RouteClassification rc
    ON r.RouteId = rc.RouteId
   AND rc.IsPhase1 = 1

LEFT JOIN stg.Agency a
    ON r.AgencyId = a.AgencyId;
GO


/*
Validation واقعی انجام‌شده
-------------------------

نتایج مشاهده‌شده:

Total Phase 1 Routes = 65

Breakdown:

RB      = 20
RE      = 32
S-Bahn  = 13

MissingOperatorCount = 0

این نتیجه تأیید می‌کند که:

- تمام 65 Route انتخاب‌شده Phase 1 وارد Dimension شده‌اند
- تعداد Routeها در هر TransportMode با Classification قبلی تطابق دارد
- برای هیچ Route انتخاب‌شده‌ای OperatorName گم نشده است
*/


SELECT
    COUNT(*) AS RouteCount
FROM dw.DimRoute;


SELECT
    TransportMode,
    COUNT(*) AS RouteCount
FROM dw.DimRoute
GROUP BY TransportMode
ORDER BY TransportMode;


SELECT
    COUNT(*) AS MissingOperatorCount
FROM dw.DimRoute
WHERE OperatorName IS NULL;


SELECT TOP (30)
    RouteKey,
    RouteId,
    RouteShortName,
    RouteLongName,
    TransportMode,
    OperatorName,
    SourceRouteType
FROM dw.DimRoute
ORDER BY
    TransportMode,
    RouteShortName;
