USE NRWTransportDW;
GO

/*
هدف
---
ایجاد Dimension تاریخ برای Data Warehouse فاز اول پروژه.

Grain
-----
هر ردیف = یک تاریخ تقویمی

چرا این Dimension لازم است؟
---------------------------
Fact Table شامل میلیون‌ها رکورد Trip-Stop برنامه‌ریزی‌شده است.

وجود یک DimDate مستقل باعث می‌شود گزارش‌ها و تحلیل‌ها بتوانند به شکل استاندارد
بر اساس موارد زیر فیلتر و گروه‌بندی شوند:

- تاریخ
- روز هفته
- شماره هفته
- ماه
- فصل
- سال
- روز کاری / آخر هفته

این کار باعث می‌شود محاسبات تقویمی به‌صورت تکراری در Queryها یا Power BI انجام نشوند.

بازه زمانی Phase 1
------------------
بازه DimDate بر اساس داده واقعی موجود در wrk.Phase1TripStops تعیین شد:

FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-12

هرچند wrk.ServiceDates تا 2026-12-31 ادامه دارد،
Routeهای انتخاب‌شده RE/RB/S-Bahn در Phase 1 فقط تا 2026-12-12
رکورد Trip-Stop دارند.

بنابراین DimDate با Scope واقعی Warehouse فاز اول هماهنگ شده است.
*/


IF OBJECT_ID('dw.DimDate', 'U') IS NOT NULL
    DROP TABLE dw.DimDate;
GO


CREATE TABLE dw.DimDate
(
    DateKey         INT NOT NULL,
    FullDate        DATE NOT NULL,

    DayNumber       TINYINT NOT NULL,
    DayName         NVARCHAR(20) NOT NULL,
    DayOfWeek       TINYINT NOT NULL,

    WeekNumber      TINYINT NOT NULL,

    MonthNumber     TINYINT NOT NULL,
    MonthName       NVARCHAR(20) NOT NULL,

    QuarterNumber   TINYINT NOT NULL,
    YearNumber      SMALLINT NOT NULL,

    IsWeekend       BIT NOT NULL,

    CONSTRAINT PK_dw_DimDate
        PRIMARY KEY CLUSTERED (DateKey),

    CONSTRAINT UQ_dw_DimDate_FullDate
        UNIQUE (FullDate)
);
GO


/*
Load Calendar Dates
-------------------
DateKey با فرمت استاندارد YYYYMMDD در Data Warehouse ساخته می‌شود.

مثال:

2026-07-01 -> 20260701
*/

;WITH DateSeries AS
(
    SELECT CAST('2026-07-01' AS DATE) AS FullDate

    UNION ALL

    SELECT DATEADD(DAY, 1, FullDate)
    FROM DateSeries
    WHERE FullDate < '2026-12-12'
)
INSERT INTO dw.DimDate
(
    DateKey,
    FullDate,
    DayNumber,
    DayName,
    DayOfWeek,
    WeekNumber,
    MonthNumber,
    MonthName,
    QuarterNumber,
    YearNumber,
    IsWeekend
)
SELECT
    YEAR(FullDate) * 10000
        + MONTH(FullDate) * 100
        + DAY(FullDate) AS DateKey,

    FullDate,

    DAY(FullDate) AS DayNumber,

    DATENAME(WEEKDAY, FullDate) AS DayName,

    DATEPART(WEEKDAY, FullDate) AS DayOfWeek,

    DATEPART(ISO_WEEK, FullDate) AS WeekNumber,

    MONTH(FullDate) AS MonthNumber,

    DATENAME(MONTH, FullDate) AS MonthName,

    DATEPART(QUARTER, FullDate) AS QuarterNumber,

    YEAR(FullDate) AS YearNumber,

    CASE
        WHEN DATENAME(WEEKDAY, FullDate) IN ('Saturday', 'Sunday')
            THEN 1
        ELSE 0
    END AS IsWeekend

FROM DateSeries
OPTION (MAXRECURSION 0);
GO


/*
Validation واقعی انجام‌شده
-------------------------

نتایج مشاهده‌شده:

DateCount = 165
FirstDate = 2026-07-01
LastDate  = 2026-12-12

این Dimension دقیقاً بازه تاریخ موجود در دیتاست Phase 1 Trip-Stop را پوشش می‌دهد.
*/


SELECT
    COUNT(*) AS DateCount,
    MIN(FullDate) AS FirstDate,
    MAX(FullDate) AS LastDate
FROM dw.DimDate;


SELECT TOP (20)
    DateKey,
    FullDate,
    DayName,
    WeekNumber,
    MonthName,
    QuarterNumber,
    YearNumber,
    IsWeekend
FROM dw.DimDate
ORDER BY FullDate;
