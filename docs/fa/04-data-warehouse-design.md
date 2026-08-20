# طراحی Data Warehouse

## 1. نمای کلی

Data Warehouse فاز اول پروژه به‌صورت Star Schema برای تحلیل سرویس‌های ریلی منطقه‌ای NRW طراحی شده است.

Scope فعلی شامل:

- RE
- RB
- S-Bahn

است.

Warehouse فعلی فقط داده‌های Scheduled Timetable را شامل می‌شود.

هنوز داده عملیاتی واقعی مانند Delay، Cancellation یا Actual Arrival/Departure در آن وجود ندارد.

---

## 2. Star Schema

### وضعیت: Implemented

مدل واقعی پیاده‌سازی‌شده:

```text
                 +-------------+
                 | dw.DimDate  |
                 +-------------+
                       |
                       |
+-------------+  +------------------+  +-------------+
| dw.DimRoute |--| dw.FactTripStop |--| dw.DimStop  |
+-------------+  +------------------+  +-------------+
```

Fact Table هسته مرکزی مدل تحلیلی است.

Dimensionها اطلاعات توصیفی مربوط به:

- تاریخ
- Route
- Operator
- Stop
- Station

را فراهم می‌کنند.

---

## 3. Grain جدول Fact

### وضعیت: Implemented

Grain اصلی:

```text
هر ردیف = یک TripInstance برنامه‌ریزی‌شده در یک StopSequence
```

یعنی هر ردیف یک Stop Event برنامه‌ریزی‌شده در یک اجرای مشخص Trip است.

مثلاً:

```text
TripInstance A

StopSequence 1 -> Köln Hbf
StopSequence 2 -> Düsseldorf Hbf
StopSequence 3 -> Essen Hbf
```

سه ردیف Fact ایجاد می‌کند.

این Grain ابتدا در:

```text
wrk.Phase1TripStops
```

و سپس دوباره در:

```text
dw.FactTripStop
```

Validation شد.

Duplicate روی:

```text
TripInstanceKey + StopSequence
```

صفر بود.

---

## 4. چرا Grain سطح Trip-Stop انتخاب شد؟

این Grain امکان تحلیل موارد زیر را فراهم می‌کند:

- فعالیت Route
- فعالیت Stop و Station
- پوشش Timetable
- Frequency سرویس
- تحلیل بر اساس ساعت روز
- سرویس‌های بعد از نیمه‌شب
- مقایسه Scheduled با Actual در آینده

اگر Grain فقط در سطح Trip بود، جزئیات Stop از بین می‌رفت.

اگر کل داده Multimodal در همین سطح Materialize می‌شد، حجم بسیار زیادی ایجاد می‌کرد.

بنابراین Trip-Stop Grain بین Detail تحلیلی و حجم قابل مدیریت تعادل ایجاد می‌کند.

---

## 5. Fact Table

### `dw.FactTripStop`

### وضعیت: Implemented

تعداد فعلی:

```text
8,029,550 rows
```

ستون‌ها:

| Column | کاربرد |
|---|---|
| `FactTripStopKey` | شناسه یکتای Surrogate برای Fact |
| `DateKey` | اتصال به `dw.DimDate` |
| `RouteKey` | اتصال به `dw.DimRoute` |
| `StopKey` | اتصال به `dw.DimStop` |
| `TripInstanceKey` | شناسه یک اجرای واقعی Scheduled Trip |
| `StopSequence` | ترتیب Stop در Trip |
| `ScheduledArrivalDateTime` | Arrival برنامه‌ریزی‌شده نرمال‌شده |
| `ScheduledDepartureDateTime` | Departure برنامه‌ریزی‌شده نرمال‌شده |
| `ArrivalDayOffset` | تعداد روز عبورکرده از ServiceDate |
| `DepartureDayOffset` | تعداد روز عبورکرده از ServiceDate |

Primary Key خوشه‌ای:

```text
FactTripStopKey BIGINT IDENTITY
```

است.

---

## 6. TripInstanceKey به‌عنوان Degenerate Identifier

### وضعیت: Implemented

`TripInstanceKey` مستقیماً در Fact Table نگه‌داری می‌شود.

در حال حاضر Dimension جداگانه‌ای به نام:

```text
DimTrip
```

وجود ندارد.

این تصمیم در Scope فعلی مناسب است، چون تحلیل‌های اصلی بر اساس:

- Date
- Route
- Operator
- Stop
- Station
- Timetable Event

انجام می‌شوند.

`TripInstanceKey` امکان Group کردن Stopهای متعلق به یک Trip را بدون نیاز به Dimension جدا فراهم می‌کند.

اگر در آینده ویژگی‌های توصیفی زیادی در سطح Trip لازم شوند، ساخت `DimTrip` قابل بررسی است.

### وضعیت DimTrip

```text
Planned only if required
```

---

## 7. Dimension تاریخ

### `dw.DimDate`

### وضعیت: Implemented

Grain:

```text
هر ردیف = یک تاریخ
```

بازه فعلی:

```text
2026-07-01 تا 2026-12-12
```

تعداد:

```text
165 rows
```

ستون‌های مهم:

- `DateKey`
- `FullDate`
- `DayNumber`
- `DayName`
- `DayOfWeek`
- `WeekNumber`
- `MonthNumber`
- `MonthName`
- `QuarterNumber`
- `YearNumber`
- `IsWeekend`

`DateKey` با فرمت:

```text
YYYYMMDD
```

ساخته شده است.

مثال:

```text
2026-07-01 -> 20260701
```

---

## 8. Dimension مسیر

### `dw.DimRoute`

### وضعیت: Implemented

Grain:

```text
هر ردیف = یک RouteId در Scope Phase 1
```

تعداد:

```text
65 Route
```

ستون‌ها:

- `RouteKey`
- `RouteId`
- `RouteShortName`
- `RouteLongName`
- `TransportMode`
- `AgencyId`
- `OperatorName`
- `SourceRouteType`

Modeهای موجود:

```text
RE
RB
S-Bahn
```

توزیع:

| Mode | Routes |
|---|---:|
| RE | 32 |
| RB | 20 |
| S-Bahn | 13 |
| **Total** | **65** |

برای تمام Routeها مقدار `OperatorName` وجود دارد.

---

## 9. Surrogate Key مسیر

Business Key اصلی GTFS:

```text
RouteId
```

در Dimension حفظ شده است.

اما در Fact Table از:

```text
RouteKey INT IDENTITY
```

استفاده می‌شود.

این کار مانع تکرار میلیون‌ها بار RouteId متنی در Fact Table می‌شود.

---

## 10. Dimension ایستگاه

### `dw.DimStop`

### وضعیت: Implemented

Grain:

```text
هر ردیف = یک StopId استفاده‌شده در Phase 1
```

تعداد:

```text
1,236 Stop
```

ستون‌ها:

- `StopKey`
- `StopId`
- `StopName`
- `ParentStationId`
- `ParentStationName`
- `PlatformCode`
- `Latitude`
- `Longitude`
- `LocationType`
- `WheelchairBoarding`

Validation:

```text
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0
```

---

## 11. مدل Parent Station

در GTFS ممکن است Platformهای مختلف یک Station دارای StopId جداگانه باشند.

مثلاً:

```text
Platform Stop A
Platform Stop B
Platform Stop C
        |
        v
     Köln Hbf
```

به همین دلیل هم:

```text
StopName
```

و هم:

```text
ParentStationName
```

ذخیره شده‌اند.

این امکان تحلیل در دو سطح را فراهم می‌کند:

- Platform / Stop
- Station

در تحلیل Station از:

```text
COALESCE(ParentStationName, StopName)
```

استفاده شده است.

---

## 12. Surrogate Key ایستگاه

Business Key منبع:

```text
StopId
```

در Dimension حفظ می‌شود.

Fact Table به‌جای آن از:

```text
StopKey INT IDENTITY
```

استفاده می‌کند.

این تصمیم حجم ذخیره‌سازی و هزینه Join روی شناسه‌های متنی طولانی را کاهش می‌دهد.

---

## 13. طراحی DateKey

برای `DimDate` از Identity Key استفاده نشده است.

در عوض:

```text
DateKey = YYYYMMDD
```

است.

مثال:

```text
2026-08-21 -> 20260821
```

این نوع Key:

- کوچک
- خوانا
- ثابت
- مناسب Join

است.

---

## 14. Resolve کردن Dimension Keyها

### وضعیت: Implemented

Fact Table از:

```text
wrk.vPhase1TripStopsNormalized
```

Load شد.

Mappingها:

```text
ServiceDate -> DimDate.DateKey
RouteId     -> DimRoute.RouteKey
StopId      -> DimStop.StopKey
```

با `INNER JOIN` انجام شدند.

نتیجه Validation:

```text
wrk.Phase1TripStops = 8,029,550
dw.FactTripStop     = 8,029,550
```

بنابراین هیچ ردیفی هنگام Resolve شدن Dimension Keyها حذف نشده است.

---

## 15. طراحی زمان GTFS

### وضعیت: Implemented

GTFS اجازه می‌دهد زمان‌هایی مثل:

```text
24:00:00
25:15:00
26:30:00
```

وجود داشته باشند.

به همین دلیل مقدار خام GTFS مستقیماً به SQL `TIME` تبدیل نشده است.

در Transformation Layer ستون‌های زیر ساخته شدند:

```text
ScheduledArrivalDateTime
ScheduledDepartureDateTime
ArrivalDayOffset
DepartureDayOffset
```

مثال:

```text
ServiceDate = 2026-07-01
GTFS Time   = 24:00:00

Result:
2026-07-02 00:00:00

DayOffset = 1
```

تعداد Stop Eventهای بعد از نیمه‌شب:

```text
139,241
```

بود.

---

## 16. Strategy مربوط به Load جدول Fact

### وضعیت: Implemented

ابتدا Fact Table بدون Reporting Index ساخته شد.

ترتیب واقعی:

```text
Create Fact Table
       |
       v
Load Fact Data
       |
       v
Validate Row Count
       |
       v
Validate Grain
       |
       v
Create Analytical Indexes
```

دلیل:

اگر Indexها قبل از Load ساخته می‌شدند، SQL Server هنگام Insert بیش از 8 میلیون ردیف باید Indexها را هم دائماً Update می‌کرد.

---

## 17. Indexهای Fact Table

### وضعیت: Implemented

دو Nonclustered Index ساخته شد.

### Index تحلیلی Date / Route / Stop

```text
IX_FactTripStop_DateRouteStop
(DateKey, RouteKey, StopKey)
```

کاربرد:

- تحلیل تاریخ
- تحلیل Route
- تحلیل Stop
- Grouping
- Filterهای آینده Power BI

### Index مربوط به TripInstance

```text
IX_FactTripStop_TripInstance
(TripInstanceKey, StopSequence)
```

کاربرد:

- بازیابی Stopهای یک Trip
- حفظ ترتیب Stopها
- تحلیل سریع یک TripInstance

---

## 18. Foreign Key Constraints

### وضعیت: Planned

ارتباط‌های منطقی:

```text
FactTripStop.DateKey
    -> DimDate.DateKey

FactTripStop.RouteKey
    -> DimRoute.RouteKey

FactTripStop.StopKey
    -> DimStop.StopKey
```

وجود دارند.

اما Physical Foreign Keyها هنوز واقعاً ساخته نشده‌اند.

بنابراین وضعیت آنها:

```text
Planned
```

است.

---

## 19. Analytical View

### `dw.vTripStopAnalytics`

### وضعیت: Implemented

برای استفاده ساده‌تر از Star Schema یک View تحلیلی ساخته شد.

این View:

```text
FactTripStop
+
DimDate
+
DimRoute
+
DimStop
```

را Join می‌کند.

خروجی شامل موارد قابل فهم Business است:

- Service Date
- Route
- Transport Mode
- Operator
- Stop
- Parent Station
- Coordinates
- Scheduled Arrival
- Scheduled Departure

View داده را Duplicate نمی‌کند و فقط یک Join Layer قابل استفاده مجدد است.

---

## 20. نتایج اولیه Warehouse

### وضعیت: SQL Validation واقعی

Scheduled Stop Count به تفکیک Mode:

| Mode | Scheduled Stop Count |
|---|---:|
| S-Bahn | 3,748,784 |
| RE | 2,536,487 |
| RB | 1,744,279 |

نمونه Routeهای پرتراکم:

```text
S1  = 611,744
S11 = 593,650
S6  = 507,587
```

نمونه Stationهای پرتراکم:

```text
Düsseldorf Hbf      = 162,531
Dortmund Hbf        = 139,004
Essen Hauptbahnhof  = 137,343
Köln Hbf            = 85,188
```

این اعداد فقط:

```text
Scheduled Trip-Stop Event Count
```

هستند.

این اعداد نشان‌دهنده موارد زیر نیستند:

- Passenger Count
- تعداد Train یکتا
- Delay
- Cancellation
- Punctuality

---

## 21. Scope فعلی Warehouse

### Implemented

```text
RE
RB
S-Bahn
```

### هنوز Implement نشده

```text
Bus
Tram
Metro / U-Bahn
ICE / IC
Actual Arrival
Actual Departure
Delay
Cancellation
Passenger Count
```

داده کامل GTFS همچنان در لایه Staging حفظ شده است و امکان توسعه آینده وجود دارد.

---

## 22. وضعیت فعلی Data Warehouse

Warehouse فعلی شامل:

```text
dw.DimDate        -> 165 rows
dw.DimRoute       -> 65 rows
dw.DimStop        -> 1,236 rows
dw.FactTripStop   -> 8,029,550 rows
```

است.

این ساختار اولین Star Schema واقعی و پیاده‌سازی‌شده پروژه است.

مدل اکنون برای Scheduled Data Analytics و اتصال آینده به Power BI آماده است.

برای Operational Performance Analytics واقعی، در مرحله بعد به یک Source معتبر Actual / Realtime نیاز خواهیم داشت.
