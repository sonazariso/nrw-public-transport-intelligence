# فرآیند ETL

## 1. نمای کلی

Pipeline فعلی ETL داده Scheduled GTFS در چهار مرحله منطقی انجام می‌شود:

```text
Raw GTFS Files
      |
      v
Staging Layer (stg)
      |
      v
Transformation Layer (wrk)
      |
      v
Data Warehouse Layer (dw)
```

Scope فعلی ETL شامل:

- RE
- RB
- S-Bahn

است.

داده Actual عملیاتی هنوز وارد این Pipeline نشده است.

---

## 2. اصول طراحی ETL

فرآیند فعلی بر اساس این اصول ساخته شده است:

- حفظ کامل Source Data
- نزدیک نگه داشتن Staging به Source
- اعمال Business Scope بعد از Ingestion
- Validation قبل از Transformationهای بزرگ
- کاهش حجم داده قبل از Materialization نهایی
- حفظ GTFS semantics مانند زمان‌های بالاتر از 24:00
- استفاده از Surrogate Key در Warehouse
- مقایسه Row Count بین Layerها
- ساخت Reporting Index بعد از Loadهای بزرگ

---

## 3. مرحله 1 — دریافت Raw GTFS

### وضعیت: Implemented

GTFS رسمی حمل‌ونقل عمومی NRW دانلود شد.

فایل‌ها:

```text
agency.txt
calendar.txt
calendar_dates.txt
feed_info.txt
routes.txt
shapes.txt
stop_times.txt
stops.txt
transfers.txt
trips.txt
```

Raw Fileها قبل از Transformation حفظ شدند.

بزرگ‌ترین فایل:

```text
stop_times.txt
```

حدود:

```text
1.12 GB
```

حجم داشت.

به دلیل حجم بالا، برای مشاهده نمونه رکوردهای آن از PowerShell استفاده شد.

---

## 4. مرحله 2 — آماده‌سازی Database

### وضعیت: Implemented

Database:

```text
NRWTransportDW
```

ساخته شد.

سه Schema اصلی:

```text
stg
wrk
dw
```

استفاده شدند.

| Schema | وظیفه |
|---|---|
| `stg` | نگه‌داری Relational Data نزدیک به Source |
| `wrk` | Transformation و داده‌های میانی |
| `dw` | Star Schema تحلیلی |

---

## 5. مرحله 3 — Load داده GTFS در Staging

### وضعیت: Implemented

جداول اصلی Staging:

```text
stg.Agency
stg.Routes
stg.Trips
stg.Stops
stg.Calendar
stg.CalendarDates
stg.StopTimes
stg.StopTimesImport
stg.FeedInfo
```

تعداد ردیف‌های مشاهده‌شده:

| Table | Rows |
|---|---:|
| `stg.Agency` | 76 |
| `stg.Routes` | 5,949 |
| `stg.Trips` | 474,978 |
| `stg.Stops` | 104,632 |
| `stg.Calendar` | 9,430 |
| `stg.CalendarDates` | 406,747 |
| `stg.StopTimes` | 10,907,141 |

---

## 6. مرحله 4 — Import فایل بزرگ StopTimes

### وضعیت: Implemented

به دلیل بیش از 10 میلیون ردیف در `stop_times.txt`، یک Import Table جدا ساخته شد:

```text
stg.StopTimesImport
```

ابتدا Source در این جدول Load شد و سپس داده وارد:

```text
stg.StopTimes
```

شد.

تعداد نهایی:

```text
10,907,141 rows
```

---

## 7. مرحله 5 — Data Quality اولیه Staging

### وضعیت: Implemented برای Queryهای واقعاً اجراشده

Referential Checkهای مهم انجام شدند.

نتایج:

```text
Missing Trip Reference  = 0
Missing Stop Reference  = 0
Missing Route Reference = 0
ServiceId بدون Calendar = 0
```

Duplicate روی:

```text
TripId + StopSequence
```

بررسی شد.

نتیجه:

```text
0
```

Profiling زمان GTFS:

```text
TimesAfter24      = 278,425
InvalidTimeFormat = 0
```

بنابراین زمان‌های بزرگ‌تر از `24:00:00` رفتار معتبر GTFS هستند، نه Data Error.

---

## 8. مرحله 6 — ساخت ServiceDates

### وضعیت: Implemented

جدول:

```text
wrk.ServiceDates
```

از:

```text
stg.Calendar
stg.CalendarDates
```

ساخته شد.

Transformation شامل:

- Expand کردن Date Range
- اعمال Weekday Flags
- اضافه کردن ExceptionType = 1
- حذف ExceptionType = 2

Grain:

```text
هر ردیف = یک ServiceId در یک ServiceDate
```

نتیجه:

```text
406,747 rows
9,430 ServiceId
2026-07-01 تا 2026-12-31
```

---

## 9. مرحله 7 — ساخت TripInstances

### وضعیت: Implemented

جدول:

```text
wrk.TripInstances
```

با Join بین:

```text
stg.Trips
wrk.ServiceDates
```

ساخته شد.

Grain:

```text
هر ردیف = یک TripId در یک ServiceDate
```

نتیجه:

```text
26,356,341 rows
184 Service Days
```

---

## 10. مرحله 8 — بهینه‌سازی TripId

### وضعیت: Implemented

طراحی اولیه شامل:

```text
TripId NVARCHAR(500)
```

در Composite Clustered Key بود.

SQL Server Warning مربوط به Key Length داد.

Profiling واقعی:

```text
Minimum = 19
Maximum = 66
Average ≈ 44.41
```

در نتیجه طراحی به:

```text
TripId NVARCHAR(100)
TripInstanceKey BIGINT IDENTITY
```

تغییر کرد.

Business Key:

```text
TripId + ServiceDate
```

با Unique Index حفظ شد.

---

## 11. مرحله 9 — Profiling RouteType

### وضعیت: Implemented

توزیع RouteType بررسی شد.

نتایج مهم:

```text
0   = 586
1   = 511
3   = 4,647
4   = 2
106 = 52
109 = 123
405 = 28
```

برخلاف انتظار اولیه، `RouteType = 2` برای سرویس‌های Regional Rail موردنظر وجود نداشت.

Feed از Extended GTFS Route Types استفاده می‌کرد.

---

## 12. مرحله 10 — Route Classification

### وضعیت: Implemented

جدول:

```text
wrk.RouteClassification
```

ساخته شد.

Business Ruleها:

```text
106 + RE prefix -> RE
106 + RB prefix -> RB
109 + S prefix  -> S-Bahn
```

نتایج:

| TransportMode | Phase 1 | Routes |
|---|---:|---:|
| RE | Yes | 32 |
| RB | Yes | 20 |
| S-Bahn | Yes | 13 |
| Other Rail | No | 110 |

تعداد Routeهای Phase 1:

```text
65
```

---

## 13. مرحله 11 — تخمین حجم داده

### وضعیت: Implemented

قبل از ساخت Trip-Stop Dataset، حجم Join تخمین زده شد.

کل GTFS:

```text
602,397,175 rows
```

RouteType 106/109:

```text
12,481,010 rows
```

Scope نهایی:

```text
8,029,550 rows
```

این مرحله از Materialize شدن غیرضروری بیش از 600 میلیون ردیف جلوگیری کرد.

---

## 14. مرحله 12 — Performance Index قبل از Join بزرگ

### وضعیت: Implemented

روی:

```text
stg.StopTimes(TripId)
```

Index ساخته شد:

```text
IX_stg_StopTimes_TripId
```

همچنین روی `wrk.TripInstances` Index زیر ساخته شد:

```text
(RouteId, TripId)
```

با Include:

```text
TripInstanceKey
ServiceDate
```

این Indexها Join و Phase 1 Filtering را سریع‌تر می‌کنند.

---

## 15. مرحله 13 — ساخت Phase1TripStops

### وضعیت: Implemented

جدول:

```text
wrk.Phase1TripStops
```

از Join این سه منبع ساخته شد:

```text
wrk.TripInstances
wrk.RouteClassification
stg.StopTimes
```

Grain:

```text
هر ردیف = یک TripInstance در یک StopSequence
```

نتیجه:

```text
8,029,550 rows
```

تفکیک:

| Mode | Rows |
|---|---:|
| RB | 1,744,279 |
| RE | 2,536,487 |
| S-Bahn | 3,748,784 |

Duplicate:

```text
0
```

---

## 16. مرحله 14 — Normalization زمان GTFS

### وضعیت: Implemented

GTFS زمان‌هایی مثل:

```text
24:00:00
25:10:00
26:35:00
```

را مجاز می‌داند.

بنابراین Raw Time مستقیماً به `TIME` تبدیل نشد.

View:

```text
wrk.vPhase1TripStopsNormalized
```

ساخته شد.

ستون‌های محاسبه‌شده:

```text
ScheduledArrivalDateTime
ScheduledDepartureDateTime
ArrivalDayOffset
DepartureDayOffset
```

تعداد After-Midnight Stopها:

```text
139,241
```

نمونه:

```text
ServiceDate      = 2026-07-01
ScheduledArrival = 24:00:00
Result           = 2026-07-02 00:00:00
ArrivalDayOffset = 1
```

---

## 17. مرحله 15 — ساخت DimDate

### وضعیت: Implemented

جدول:

```text
dw.DimDate
```

ساخته شد.

بازه:

```text
2026-07-01 تا 2026-12-12
```

تعداد:

```text
165
```

---

## 18. مرحله 16 — ساخت DimRoute

### وضعیت: Implemented

Dimension از:

```text
stg.Routes
wrk.RouteClassification
stg.Agency
```

ساخته شد.

فقط Routeهای:

```text
IsPhase1 = 1
```

Load شدند.

نتیجه:

```text
65 Route
```

تفکیک:

```text
RE      = 32
RB      = 20
S-Bahn  = 13
```

Missing Operator:

```text
0
```

---

## 19. مرحله 17 — ساخت DimStop

### وضعیت: Implemented

فقط StopIdهای استفاده‌شده در Phase 1 Load شدند.

نتیجه:

```text
1,236 Stop
```

Validation:

```text
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0
```

---

## 20. مرحله 18 — Load جدول Fact

### وضعیت: Implemented

Fact Table:

```text
dw.FactTripStop
```

از:

```text
wrk.vPhase1TripStopsNormalized
```

Load شد.

Mapping:

```text
ServiceDate -> DateKey
RouteId     -> RouteKey
StopId      -> StopKey
```

نتیجه:

```text
8,029,550 rows
```

Validation:

```text
WorkRowCount = 8,029,550
FactRowCount = 8,029,550
```

هیچ Row از دست نرفت.

Duplicate Grain:

```text
0
```

---

## 21. مرحله 19 — ساخت Reporting Indexها

### وضعیت: Implemented

بعد از Load Fact، دو Index ساخته شد:

```text
IX_FactTripStop_DateRouteStop
(DateKey, RouteKey, StopKey)
```

و:

```text
IX_FactTripStop_TripInstance
(TripInstanceKey, StopSequence)
```

Indexها عمداً بعد از Load ساخته شدند تا هزینه Insert میلیون‌ها Row افزایش پیدا نکند.

---

## 22. مرحله 20 — ساخت Analytical View

### وضعیت: Implemented

View نهایی SQL:

```text
dw.vTripStopAnalytics
```

ساخته شد.

این View:

```text
FactTripStop
DimDate
DimRoute
DimStop
```

را Join می‌کند.

---

## 23. مرحله 21 — Business Validation

### وضعیت: Implemented

Scheduled Stop Count بر اساس Mode:

```text
S-Bahn = 3,748,784
RE     = 2,536,487
RB     = 1,744,279
```

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

این اعداد فقط Scheduled Trip-Stop Event هستند.

---

## 24. مرز فعلی ETL

ETL پیاده‌سازی‌شده فعلاً در:

```text
dw.vTripStopAnalytics
```

به پایان می‌رسد.

موارد زیر هنوز Planned هستند:

```text
Power BI Semantic Model
Dashboard
Actual / Realtime Data
Delay / Cancellation Processing
AI Workflow
```

---

## 25. خلاصه Pipeline

```text
NRW GTFS Raw Files
        |
        v
stg
        |
        v
ServiceDates
        |
        v
TripInstances
        |
        v
Route Classification
        |
        v
Phase1TripStops
        |
        v
Time Normalization
        |
        v
DimDate / DimRoute / DimStop
        |
        v
FactTripStop
        |
        v
Reporting Indexes
        |
        v
dw.vTripStopAnalytics
```

ETL مربوط به Scheduled Data تا این مرحله پیاده‌سازی و Validation شده است.
