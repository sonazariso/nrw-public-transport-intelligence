# معماری داده

## 1. نمای کلی معماری

این پروژه از یک معماری لایه‌ای استفاده می‌کند تا داده خام، داده Staging، منطق Transformation، ساختار نهایی Data Warehouse و لایه گزارش‌دهی از یکدیگر جدا باشند.

معماری فعلی:

```text
Official GTFS Source
        ↓
Raw Files
        ↓
SQL Server Staging Layer
        ↓
Working / Transformation Layer
        ↓
Data Warehouse Layer
        ↓
Power BI
```

هدف اصلی این معماری، ایجاد فرایندی شفاف، قابل بررسی، قابل تکرار و قابل توسعه است.

## 2. لایه Raw

لایه Raw شامل فایل‌های اصلی GTFS است که مستقیماً از منبع رسمی دانلود شده‌اند.

محل فعلی فایل‌ها:

`C:\NRW-Rail-Intelligence\Data\raw\gtfs\google_transit`

فایل‌های اصلی شامل:

- `agency.txt`
- `routes.txt`
- `trips.txt`
- `stops.txt`
- `stop_times.txt`
- `calendar.txt`
- `calendar_dates.txt`
- `feed_info.txt`

فایل‌های Raw باید بدون تغییر نگهداری شوند.

هیچ Business Transformation مستقیمی روی این فایل‌ها انجام نمی‌شود.

هدف از نگهداری Raw Data:

- امکان بازتولید فرایند
- Audit
- Reprocessing
- Debugging
- مقایسه Snapshotهای تاریخی

## 3. دیتابیس SQL Server

دیتابیس اصلی پروژه:

`NRWTransportDW`

SQL Server پلتفرم اصلی پروژه برای موارد زیر است:

- Data Ingestion
- Transformation
- Data Quality Validation
- Data Warehouse Modeling

در حال حاضر سه Schema اصلی داریم:

- `stg`
- `wrk`
- `dw`

## 4. لایه Staging

Schema `stg` شامل داده‌هایی است که با حداقل تغییر از GTFS وارد SQL Server شده‌اند.

جدول‌های فعلی:

- `stg.Agency`
- `stg.Routes`
- `stg.Trips`
- `stg.Stops`
- `stg.StopTimes`
- `stg.Calendar`
- `stg.CalendarDates`
- `stg.FeedInfo`

اهداف اصلی Staging:

- حفظ مقادیر منبع
- فراهم کردن دسترسی SQL به داده GTFS
- بررسی ساختار داده
- شناسایی مشکلات Data Quality
- فراهم کردن پایه برای ETL قابل تکرار

منطق Business نباید به شکل گسترده داخل این لایه قرار بگیرد.

## 5. لایه Working / Transformation

Schema `wrk` برای Transformationهای میانی و منطق Business قابل استفاده مجدد طراحی شده است.

نمونه Objectهای برنامه‌ریزی‌شده:

- `wrk.ServiceDates`
- `wrk.RouteClassification`
- `wrk.NormalizedOperators`
- `wrk.NormalizedStops`
- `wrk.TripServiceDates`

وظیفه این لایه تبدیل ساختارهای Source-oriented به ساختارهای Business-oriented است.

نمونه Transformationها:

- تبدیل قوانین Calendar به Service Dateهای واقعی
- اعمال Exceptionهای `calendar_dates`
- Classification نوع وسیله حمل‌ونقل
- Normalization نام Operatorها
- حل Parent Station relationships
- آماده‌سازی داده برای بارگذاری Dimensions و Facts

این لایه مستقیماً برای Reporting در Power BI استفاده نمی‌شود.

## 6. لایه Data Warehouse

Schema `dw` شامل مدل نهایی تحلیلی یا Star Schema خواهد بود.

Dimensionهای برنامه‌ریزی‌شده:

- `dw.DimDate`
- `dw.DimTime`
- `dw.DimRoute`
- `dw.DimTrip`
- `dw.DimStop`
- `dw.DimOperator`
- `dw.DimTransportMode`

Fact Table اصلی:

`dw.FactTripStop`

Grain فعلی مدل:

**یک Trip برنامه‌ریزی‌شده در یک Stop و در یک Service Date مشخص.**

این Grain امکان تحلیل بر اساس موارد زیر را فراهم می‌کند:

- تاریخ
- زمان
- خط
- Trip
- Stop
- Operator
- Transport Mode

## 7. لایه Power BI

Power BI باید به Data Warehouse متصل شود، نه مستقیماً به فایل‌های خام GTFS.

این کار باعث می‌شود منطق Reporting از منطق ETL و Transformation جدا باقی بماند.

خروجی‌های تحلیلی برنامه‌ریزی‌شده:

- Punctuality
- Delay
- Cancellation
- Route Performance
- Stop Performance
- Operator Performance
- Peak-hour Reliability
- Historical Trends

تا جای ممکن Business Logic و Transformationهای اصلی باید در Data Warehouse انجام شوند و Power BI روی مدل تحلیلی آماده کار کند.

## 8. جریان داده

جریان فعلی End-to-End:

```text
OpenData ÖPNV
     ↓
GTFS ZIP Download
     ↓
Raw GTFS Text Files
     ↓
BULK INSERT
     ↓
stg Schema
     ↓
Data Quality Checks
     ↓
wrk Schema
     ↓
Business Transformations
     ↓
dw Star Schema
     ↓
Power BI
```

## 9. اصول طراحی

### حفظ Raw Data

فایل‌های اصلی منبع هیچ‌گاه تغییر نمی‌کنند.

### جداسازی Source و Business Logic

ساختار اصلی GTFS در Staging حفظ می‌شود و منطق Business در لایه‌های بعدی اعمال می‌شود.

### قابل تکرار بودن ETL

Load و Transformationها باید قابل تکرار و در آینده قابل Automation باشند.

### مستقل بودن Reporting

Power BI باید داده آماده و Curated شده دریافت کند و Transformationهای اصلی در آن انجام نشود.

### قابلیت توسعه برای منابع جدید

معماری باید در آینده بتواند منابعی مانند موارد زیر را اضافه کند:

- GTFS Realtime
- NRW Quality Data
- Deutsche Bahn APIs
- Weather Data
- Incident Data

بدون اینکه کل معماری دوباره طراحی شود.

## 10. وضعیت فعلی پروژه

تا این مرحله موارد زیر انجام شده‌اند:

- ساخت Database
- ساخت Schemaها
- ساخت Staging Tables
- Import اولیه GTFS
- Load و Validation چند میلیون رکورد

مراحل اصلی بعدی:

- Data Quality Validation
- Working Layer Transformations
- Dimensional Modeling
- Fact Table Creation
- Power BI Modeling
