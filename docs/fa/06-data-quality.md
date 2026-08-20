# کیفیت داده

## 1. نمای کلی

Data Quality در چند مرحله از Pipeline پروژه NRW Rail Intelligence بررسی شده است.

Validationهای فعلی روی این موارد تمرکز دارند:

- Referential Consistency
- Duplicate Detection
- اعتبار فرمت زمان GTFS
- کامل بودن Transformation
- حفظ Grain
- کامل بودن Dimensionها
- تطبیق Row Count بین Layerها

فقط مواردی در این سند به‌عنوان Passed ثبت شده‌اند که Query آنها واقعاً اجرا و نتیجه آنها بررسی شده است.

---

## 2. ارتباط StopTimes با Trips

### وضعیت: Implemented و Validated

سؤال Validation:

```text
آیا تمام TripIdهای موجود در StopTimes در stg.Trips وجود دارند؟
```

نتیجه:

```text
MissingTripReferences = 0
```

نتیجه‌گیری:

تمام StopTimeها به Trip معتبر متصل هستند.

---

## 3. ارتباط StopTimes با Stops

### وضعیت: Implemented و Validated

سؤال:

```text
آیا تمام StopIdهای StopTimes در stg.Stops وجود دارند؟
```

نتیجه:

```text
MissingStopReferences = 0
```

نتیجه‌گیری:

تمام رکوردهای StopTimes به Stop معتبر اشاره می‌کنند.

---

## 4. ارتباط Trips با Routes

### وضعیت: Implemented و Validated

سؤال:

```text
آیا تمام RouteIdهای Trips در stg.Routes وجود دارند؟
```

نتیجه:

```text
MissingRouteReferences = 0
```

نتیجه‌گیری:

تمام Tripها دارای Route معتبر هستند.

---

## 5. بررسی Calendar برای ServiceId

### وضعیت: Implemented و Validated

سؤال:

```text
آیا تمام ServiceIdهای مورد استفاده Trips در Calendar تعریف شده‌اند؟
```

نتیجه:

```text
ServiceIdsWithoutCalendarDefinition = 0
```

بنابراین تمام ServiceIdهای استفاده‌شده دارای Calendar Definition هستند.

---

## 6. بررسی Grain در StopTimes

### وضعیت: Implemented و Validated

ترکیب زیر بررسی شد:

```text
TripId + StopSequence
```

نتیجه:

```text
Duplicate = 0
```

بنابراین برای هر Trip یک StopSequence تکراری وجود ندارد.

---

## 7. Profiling زمان GTFS

### وضعیت: Implemented و Validated

GTFS اجازه می‌دهد Hour از 24 بیشتر شود.

نتیجه Profiling:

```text
TimesAfter24 = 278,425
```

این مقدار Data Error نیست.

نمونه مقادیر معتبر:

```text
24:00:00
25:15:00
26:30:00
```

هستند.

---

## 8. بررسی فرمت زمان GTFS

### وضعیت: Implemented و Validated

مقادیر Time از نظر Format بررسی شدند.

نتیجه:

```text
InvalidTimeFormat = 0
```

بنابراین در Validation اجراشده هیچ Time String نامعتبر شناسایی نشد.

---

## 9. Uniqueness در ServiceDates

### وضعیت: Implemented و Validated

Grain جدول:

```text
wrk.ServiceDates
```

عبارت است از:

```text
ServiceId + ServiceDate
```

Duplicate بررسی شد.

نتیجه:

```text
0
```

پس هر Service روی هر تاریخ فقط یک بار وجود دارد.

---

## 10. Exceptionهای حذف‌شده Calendar

### وضعیت: Implemented و Validated

در GTFS:

```text
ExceptionType = 2
```

به معنی حذف سرویس در یک تاریخ است.

بعد از ساخت `wrk.ServiceDates` بررسی شد که این تاریخ‌ها اشتباهی باقی نمانده باشند.

نتیجه:

```text
RemovedServicesStillPresent = 0
```

پس Removal Exceptionها درست اعمال شده‌اند.

---

## 11. پوشش ServiceDates

### وضعیت: Implemented و Validated

نتایج:

```text
ServiceDateCount     = 406,747
DistinctServiceCount = 9,430
FirstServiceDate     = 2026-07-01
LastServiceDate      = 2026-12-31
```

این خروجی قبل از ادامه Pipeline بررسی شد.

---

## 12. Profiling طول TripId

### وضعیت: Implemented و بررسی‌شده

قبل از نهایی کردن طراحی Index در `wrk.TripInstances`، طول TripId بررسی شد.

نتیجه:

```text
Minimum = 19
Maximum = 66
Average ≈ 44.41
```

بر اساس این Profiling، طراحی اولیه بیش‌ازحد بزرگ اصلاح شد.

نوع نهایی:

```text
TripId NVARCHAR(100)
```

شد.

---

## 13. Validation جدول TripInstances

### وضعیت: Implemented و Validated

تعداد:

```text
TripInstanceCount = 26,356,341
```

بازه:

```text
FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-31
ServiceDayCount  = 184
```

Unique Index روی:

```text
TripId + ServiceDate
```

نیز با موفقیت ساخته شد.

---

## 14. Profiling RouteType

### وضعیت: Implemented و بررسی‌شده

RouteTypeهای Source بررسی شدند.

نتایج:

| RouteType | Routes |
|---:|---:|
| 0 | 586 |
| 1 | 511 |
| 3 | 4,647 |
| 4 | 2 |
| 106 | 52 |
| 109 | 123 |
| 405 | 28 |

یک نتیجه مهم این بود که:

```text
RouteType = 2
```

برای سرویس‌های Regional Rail موردنظر وجود نداشت.

بررسی بیشتر:

```text
RouteType 106:
RE = 32
RB = 20

RouteType 109:
S-prefix = 13
Other = 110
```

انجام شد.

---

## 15. Validation مربوط به Route Classification

### وضعیت: Implemented و Validated

نتیجه نهایی:

| TransportMode | IsPhase1 | RouteCount |
|---|---:|---:|
| RE | 1 | 32 |
| RB | 1 | 20 |
| S-Bahn | 1 | 13 |
| Other Rail | 0 | 110 |

تعداد نهایی Phase 1:

```text
65 Route
```

بود.

---

## 16. تخمین حجم Trip-Stop

### وضعیت: Implemented و بررسی‌شده

قبل از Materialization، حجم Join تخمین زده شد.

نتایج:

```text
Full GTFS:
602,397,175 rows

RouteType 106/109:
12,481,010 rows

Final Phase 1:
8,029,550 rows
```

این Validation برای Performance و Scope Control استفاده شد.

---

## 17. Validation تعداد Phase1TripStops

### وضعیت: Implemented و Validated

تعداد کل:

```text
8,029,550
```

تفکیک:

| Mode | Rows |
|---|---:|
| RB | 1,744,279 |
| RE | 2,536,487 |
| S-Bahn | 3,748,784 |
| **Total** | **8,029,550** |

جمع Modeها دقیقاً با Total برابر است.

---

## 18. Validation Grain در Phase1TripStops

### وضعیت: Implemented و Validated

Grain مورد انتظار:

```text
TripInstanceKey + StopSequence
```

نتیجه Duplicate Check:

```text
0
```

پس Grain موردنظر حفظ شده است.

---

## 19. بررسی بازه Phase 1

### وضعیت: Implemented و بررسی‌شده

نتایج:

```text
FirstServiceDate = 2026-07-01
LastServiceDate  = 2026-12-12
ServiceDayCount  = 165
```

این بازه از `wrk.ServiceDates` کوتاه‌تر است.

این اختلاف بررسی شد و به دلیل Scope محدود 65 Route در Phase 1 تلقی شد، نه اینکه خودکار Data Quality Error در نظر گرفته شود.

---

## 20. Validation زمان‌های بعد از نیمه‌شب

### وضعیت: Implemented و Validated

View نرمال‌شده روی زمان‌های >= 24 تست شد.

نتیجه:

```text
AfterMidnightStopCount = 139,241
```

نمونه بررسی‌شده:

```text
ServiceDate              = 2026-07-01
ScheduledArrival         = 24:00:00
ScheduledArrivalDateTime = 2026-07-02 00:00:00
ArrivalDayOffset         = 1
```

این نتیجه صحت Transformation را تأیید کرد.

---

## 21. Validation جدول DimDate

### وضعیت: Implemented و Validated

نتیجه:

```text
DateCount = 165
FirstDate = 2026-07-01
LastDate  = 2026-12-12
```

بازه Dimension دقیقاً با Phase 1 هماهنگ است.

---

## 22. Validation جدول DimRoute

### وضعیت: Implemented و Validated

تعداد:

```text
RouteCount = 65
```

تفکیک:

```text
RE      = 32
RB      = 20
S-Bahn  = 13
```

Missing Operator:

```text
MissingOperatorCount = 0
```

پس تمام Routeهای Phase 1 دارای Operator هستند.

---

## 23. Validation جدول DimStop

### وضعیت: Implemented و Validated

تعداد:

```text
StopCount = 1,236
```

نتایج:

```text
StopsWithParentStation  = 918
MissingStopNameCount    = 0
MissingCoordinatesCount = 0
```

پس تمام Stopهای انتخاب‌شده نام و مختصات دارند.

---

## 24. تطبیق Work Layer با Fact Table

### وضعیت: Implemented و Validated

تعداد ردیف‌ها مقایسه شد:

```text
wrk.Phase1TripStops = 8,029,550
dw.FactTripStop     = 8,029,550
```

نتیجه‌گیری:

هیچ Trip-Stop در Join با Dimensionها از دست نرفته است.

---

## 25. Validation Grain در Fact Table

### وضعیت: Implemented و Validated

Duplicate Check روی:

```text
TripInstanceKey + StopSequence
```

اجرا شد.

نتیجه:

```text
0
```

پس Grain نهایی Warehouse نیز سالم است.

---

## 26. Business-Level Reconciliation

### وضعیت: Implemented و بررسی‌شده

خروجی Analytical View همان Distribution مورد انتظار را تولید کرد:

```text
S-Bahn = 3,748,784
RE     = 2,536,487
RB     = 1,744,279
```

این یک Check اضافه برای سازگاری End-to-End بعد از Joinهای Star Schema است.

---

## 27. مواردی که هنوز Passed ثبت نشده‌اند

موارد زیر تا زمانی که Query آنها اجرا و نتیجه بررسی نشود، Passed در نظر گرفته نمی‌شوند:

- NULL Profiling کامل تمام ستون‌های Staging
- Physical Foreign Key Validation در Warehouse
- Power BI Model Validation
- Actual / Realtime Data Quality
- Delay Accuracy
- Cancellation Accuracy
- Operational Punctuality Reconciliation

این موارد Future Validation هستند.

---

## 28. جمع‌بندی کیفیت داده

Validationهای اصلی Scheduled Data:

```text
Source Referential Checks       -> Passed
StopTimes Grain Check           -> Passed
GTFS Time Format Check          -> Passed
Service Calendar Resolution     -> Passed
Route Classification Validation -> Passed
Trip-Stop Grain Validation      -> Passed
Dimension Completeness          -> Passed
Fact Row Reconciliation         -> Passed
Fact Grain Validation           -> Passed
```

این نتایج فقط Data Warehouse مربوط به Scheduled Data را تأیید می‌کنند.

هنوز نمی‌توان از آنها برای تأیید Delay، Cancellation یا Operational Performance استفاده کرد، چون Actual Operational Data وارد پروژه نشده است.
