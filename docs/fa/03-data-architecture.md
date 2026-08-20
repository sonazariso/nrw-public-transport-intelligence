# معماری داده

## 1. نمای کلی

پروژه NRW Rail Intelligence از یک معماری داده چندلایه استفاده می‌کند تا داده خام، Transformationها، Data Warehouse و Reporting از یکدیگر جدا باشند.

معماری فعلی که واقعاً پیاده‌سازی شده است:

```text
NRW OpenData GTFS
        |
        v
Raw GTFS Files
        |
        v
+-------------------+
|   stg - Staging   |
+-------------------+
        |
        v
+-------------------+
| wrk - Working     |
| Transformation    |
+-------------------+
        |
        v
+-------------------+
| dw - Data         |
| Warehouse         |
+-------------------+
        |
        v
dw.vTripStopAnalytics
        |
        v
Power BI
(Planned)
```

در وضعیت فعلی، Pipeline کامل داده‌های برنامه‌ریزی‌شده از GTFS رسمی NRW تا لایه تحلیلی Data Warehouse پیاده‌سازی شده است.

داده‌های عملیاتی واقعی مانند Delay و Cancellation هنوز وارد پروژه نشده‌اند.

---

## 2. لایه Source

### وضعیت: Implemented

منبع اولیه پروژه، GTFS رسمی حمل‌ونقل عمومی NRW است.

Feed دانلودشده شامل فایل‌های زیر است:

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

فایل‌های Raw قبل از هر Transformation حفظ می‌شوند.

این کار باعث می‌شود:

- داده منبع قابل بازتولید باشد
- Transformationها دوباره قابل اجرا باشند
- Business Filtering باعث از بین رفتن داده اصلی نشود

به دلیل حجم بالا، مخصوصاً `stop_times.txt`، داده Raw در Git Repository ذخیره نمی‌شود.

---

## 3. لایه Staging — `stg`

### وضعیت: Implemented

Schema به نام `stg` داده GTFS را به ساختار Relational در SQL Server منتقل می‌کند.

این لایه تا حد ممکن به ساختار Source نزدیک نگه داشته شده است.

وظایف اصلی آن:

- Load فایل‌های GTFS
- حفظ Source Identifierها
- حفظ مقادیر اصلی
- امکان Data Quality Validation
- فراهم کردن ورودی Transformationهای بعدی

جداول مهم پیاده‌سازی‌شده:

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

برای `stop_times.txt` به علت وجود بیش از 10 میلیون ردیف، یک Import Table جداگانه استفاده شد.

### اصل مهم طراحی

کل GTFS در Staging حفظ می‌شود.

Scope مربوط به RE/RB/S-Bahn در زمان Ingestion اعمال نمی‌شود.

به این ترتیب فازهای بعدی پروژه می‌توانند از همان داده برای Bus، Tram یا Metro نیز استفاده کنند.

---

## 4. لایه Working / Transformation — `wrk`

### وضعیت: Implemented

Schema به نام `wrk` شامل ساختارهای میانی Transformation است.

هدف این لایه تبدیل داده Source-Oriented در GTFS به داده Business-Oriented قبل از ورود به Data Warehouse است.

Pipeline واقعی:

```text
stg.Calendar
stg.CalendarDates
        |
        v
wrk.ServiceDates
        |
        +--------------------+
        |                    |
        v                    |
stg.Trips                    |
        |                    |
        v                    |
wrk.TripInstances            |
                             |
stg.Routes ------------------+
        |
        v
wrk.RouteClassification
        |
        v
stg.StopTimes
        |
        v
wrk.Phase1TripStops
        |
        v
wrk.vPhase1TripStopsNormalized
```

---

## 5. `wrk.ServiceDates`

### وضعیت: Implemented

این جدول تعریف‌های تقویمی GTFS را به تاریخ‌های واقعی سرویس تبدیل می‌کند.

### Grain

```text
هر ردیف = یک ServiceId در یک ServiceDate
```

این Transformation ترکیب می‌کند:

- الگوی هفتگی `stg.Calendar`
- سرویس‌های اضافه‌شده در `stg.CalendarDates`
- سرویس‌های حذف‌شده در `stg.CalendarDates`

نتیجه واقعی:

```text
406,747 Service-Date
9,430 ServiceId متمایز
از 2026-07-01 تا 2026-12-31
```

Duplicate روی `(ServiceId, ServiceDate)` بررسی شد و نتیجه صفر بود.

---

## 6. `wrk.TripInstances`

### وضعیت: Implemented

در GTFS، `trips.txt` تعریف Trip را نگه می‌دارد، نه یک ردیف مستقل برای هر روز اجرا.

`wrk.TripInstances` هر Trip را روی تاریخ‌های واقعی اجرا Expand می‌کند.

### Grain

```text
هر ردیف = یک TripId که در یک ServiceDate اجرا می‌شود
```

نتیجه:

```text
26,356,341 Trip Instance
184 روز سرویس
2026-07-01 تا 2026-12-31
```

یک Surrogate Key ایجاد شد:

```text
TripInstanceKey BIGINT IDENTITY
```

Business Key نیز:

```text
TripId + ServiceDate
```

است و با Unique Index محافظت می‌شود.

### تصمیم مهم طراحی

در طراحی اولیه `TripId NVARCHAR(500)` بخشی از Composite Clustered Key بود.

SQL Server Warning مربوط به طول Index Key نمایش داد.

Profiling واقعی نشان داد:

```text
Minimum TripId Length = 19
Maximum TripId Length = 66
Average ≈ 44.41
```

بنابراین ستون در لایه Working به `NVARCHAR(100)` کاهش یافت و Numeric Surrogate Key به‌عنوان Clustered Primary Key انتخاب شد.

---

## 7. Classification مسیرهای Phase 1

### وضعیت: Implemented

در ابتدا انتظار داشتیم Railway با:

```text
route_type = 2
```

مشخص شود.

اما Profiling Feed واقعی NRW نشان داد سرویس‌های موردنظر از Extended GTFS Route Types استفاده می‌کنند.

مقادیر مهم:

```text
RouteType 106 = 52 Route
RouteType 109 = 123 Route
```

Business Rule نهایی:

```text
RouteType 106 + RE prefix -> RE
RouteType 106 + RB prefix -> RB
RouteType 109 + S prefix  -> S-Bahn
```

Scope نهایی:

| Mode | Routes |
|---|---:|
| RE | 32 |
| RB | 20 |
| S-Bahn | 13 |
| **Total** | **65** |

110 Route دیگر از RouteType 109 با عنوان `Other Rail` نگه داشته شده ولی از Phase 1 خارج شده‌اند.

این کار باعث Auditability می‌شود؛ یعنی مشخص است این Routeها دیده و عمداً Exclude شده‌اند.

---

## 8. `wrk.Phase1TripStops`

### وضعیت: Implemented

قبل از Materialize کردن Trip-Stop، حجم داده تخمین زده شد.

حجم احتمالی کل GTFS:

```text
602,397,175 rows
```

حجم Scope نهایی RE/RB/S-Bahn:

```text
8,029,550 rows
```

به همین دلیل کل GTFS همچنان در Staging باقی می‌ماند و فقط Scope Phase 1 در لایه‌های بعدی Materialize می‌شود.

### Grain

```text
هر ردیف = یک TripInstance در یک StopSequence
```

نتیجه واقعی:

| Mode | Trip-Stop Rows |
|---|---:|
| RB | 1,744,279 |
| RE | 2,536,487 |
| S-Bahn | 3,748,784 |
| **Total** | **8,029,550** |

Duplicate روی `(TripInstanceKey, StopSequence)` بررسی شد و نتیجه صفر بود.

بازه واقعی Phase 1:

```text
2026-07-01 تا 2026-12-12
165 روز
```

---

## 9. نرمال‌سازی زمان GTFS

### وضعیت: Implemented

GTFS اجازه می‌دهد زمان از `24:00:00` عبور کند.

مثلاً:

```text
24:00:00
25:15:00
26:30:00
```

این مقادیر برای سرویس‌هایی هستند که بعد از نیمه‌شب ادامه دارند.

چون SQL Server نوع `TIME` را برای چنین مقادیری قبول نمی‌کند، مقدار خام حفظ شده و مقدار تحلیلی جداگانه ساخته شده است.

View پیاده‌سازی‌شده:

```text
wrk.vPhase1TripStopsNormalized
```

ستون‌های تحلیلی:

```text
ScheduledArrivalDateTime
ScheduledDepartureDateTime
ArrivalDayOffset
DepartureDayOffset
```

تعداد واقعی Stopهای بعد از نیمه‌شب:

```text
139,241
```

نمونه:

```text
ServiceDate          : 2026-07-01
ScheduledArrival     : 24:00:00
Normalized timestamp : 2026-07-02 00:00:00
ArrivalDayOffset     : 1
```

---

## 10. لایه Data Warehouse — `dw`

### وضعیت: Implemented

Schema به نام `dw` شامل Star Schema تحلیلی پروژه است.

ساختار فعلی:

```text
                 dw.DimDate
                     |
                     |
dw.DimRoute --- dw.FactTripStop --- dw.DimStop
```

Objectهای پیاده‌سازی‌شده:

```text
dw.DimDate
dw.DimRoute
dw.DimStop
dw.FactTripStop
dw.vTripStopAnalytics
```

---

## 11. `dw.DimDate`

### وضعیت: Implemented

### Grain

```text
هر ردیف = یک تاریخ تقویمی
```

تعداد:

```text
165 روز
2026-07-01 تا 2026-12-12
```

شامل ویژگی‌هایی مثل:

- Day
- Week
- Month
- Quarter
- Year
- Weekend Indicator

است.

---

## 12. `dw.DimRoute`

### وضعیت: Implemented

### Grain

```text
هر ردیف = یک RouteId در Scope Phase 1
```

تعداد:

```text
65 Route
```

شامل:

- RouteId
- RouteShortName
- RouteLongName
- TransportMode
- AgencyId
- OperatorName
- SourceRouteType

است.

برای تمام 65 Route مقدار OperatorName موجود است.

---

## 13. `dw.DimStop`

### وضعیت: Implemented

### Grain

```text
هر ردیف = یک StopId استفاده‌شده در Phase 1
```

تعداد:

```text
1,236 Stop
```

Validation واقعی:

```text
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0
```

وجود Parent Station امکان Roll-up از Platform/Stop به Station اصلی را فراهم می‌کند.

---

## 14. `dw.FactTripStop`

### وضعیت: Implemented

### Grain

```text
هر ردیف = یک TripInstance در یک StopSequence
```

تعداد:

```text
8,029,550 rows
```

Fact به Dimensionهای زیر متصل می‌شود:

```text
DateKey
RouteKey
StopKey
```

و شامل:

```text
TripInstanceKey
StopSequence
ScheduledArrivalDateTime
ScheduledDepartureDateTime
ArrivalDayOffset
DepartureDayOffset
```

مقایسه تعداد ردیف‌ها:

```text
wrk.Phase1TripStops = 8,029,550
dw.FactTripStop     = 8,029,550
```

بنابراین هیچ ردیفی هنگام Resolve کردن Dimension Keyها از دست نرفته است.

Duplicate روی `(TripInstanceKey, StopSequence)` نیز صفر بود.

---

## 15. Indexهای Warehouse

### وضعیت: Implemented

دو Index تحلیلی بعد از Load جدول Fact ساخته شدند:

```text
IX_FactTripStop_DateRouteStop
(DateKey, RouteKey, StopKey)
```

و:

```text
IX_FactTripStop_TripInstance
(TripInstanceKey, StopSequence)
```

Indexها بعد از Load ساخته شدند تا هزینه نگه‌داری Index هنگام Insert میلیون‌ها ردیف به Load اولیه تحمیل نشود.

---

## 16. Referential Constraints

### وضعیت: Planned

ارتباط منطقی فعلی:

```text
FactTripStop.DateKey  -> DimDate.DateKey
FactTripStop.RouteKey -> DimRoute.RouteKey
FactTripStop.StopKey  -> DimStop.StopKey
```

است.

اما Physical Foreign Key Constraintها هنوز اجرا نشده‌اند.

بنابراین در Documentation فعلی به‌عنوان Implemented ثبت نمی‌شوند.

---

## 17. Analytical View

### وضعیت: Implemented

View زیر ساخته شده است:

```text
dw.vTripStopAnalytics
```

این View اطلاعات Fact را با موارد زیر ترکیب می‌کند:

- Date
- Route
- Operator
- Stop
- Parent Station
- Scheduled timestamps

Queryهای تحلیلی واقعی برای این موارد اجرا شده‌اند:

- حجم Scheduled Stop به تفکیک Mode
- Routeهای پرتراکم
- Stationهای پرتراکم

این View فعلاً فقط Scheduled Timetable Data را نمایش می‌دهد.

---

## 18. Power BI

### وضعیت: Planned

Power BI هنوز به Warehouse متصل نشده است.

مدل آینده باید مستقیماً بر اساس Star Schema ساخته شود، نه جداول Raw یا Staging.

تحلیل‌های احتمالی Scheduled Data:

- Service Volume by Date
- Service Volume by Route
- Service Volume by Mode
- Station Activity
- Operator Coverage
- Weekday vs Weekend
- Service by Hour

بعد از پیاده‌سازی Power BI، مدل آن در سند جداگانه مستند خواهد شد.

---

## 19. داده Actual / Realtime

### وضعیت: Planned

Warehouse فعلی فقط Scheduled GTFS را دارد.

هنوز شامل موارد زیر نیست:

- Actual Arrival
- Actual Departure
- Delay
- Cancellation
- Disruption
- Punctuality

قبل از پیاده‌سازی این KPIها باید یک منبع رسمی و قابل اعتماد برای Operational Data پیدا شود.

تا قبل از آن، پروژه باید از اصطلاح:

```text
Scheduled Service Analytics
```

یا:

```text
Timetable Analytics
```

استفاده کند و داده را به‌عنوان Operational Performance معرفی نکند.

---

## 20. وضعیت فعلی معماری

معماری پیاده‌سازی‌شده فعلی:

```text
Official NRW GTFS
       |
       v
Raw Files
       |
       v
stg
       |
       v
wrk
       |
       v
Phase 1 RE / RB / S-Bahn
       |
       v
Time Normalization
       |
       v
dw Star Schema
       |
       v
Analytical SQL View
```

موارد بعدی:

```text
Power BI                  -> Planned
Actual / Realtime Data    -> Planned
Delay / Cancellation KPIs -> Planned
AI Workflow               -> Planned
```
