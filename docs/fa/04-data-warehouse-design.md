# طراحی Data Warehouse

## 1. هدف طراحی

Data Warehouse این پروژه برای تحلیل عملکرد حمل‌ونقل عمومی در ایالت NRW طراحی شده است.

مدل بر اساس ساختار Dimensional و Star Schema ساخته می‌شود تا:

- روابط بین جداول واضح باشند
- Power BI مدل ساده‌تری داشته باشد
- توسعه آینده آسان باشد
- تحلیل‌های مختلف روی Fact اصلی انجام شود

فاز اول روی این سرویس‌ها تمرکز دارد:

- RE
- RB
- S-Bahn

در فازهای بعدی می‌توان موارد زیر را اضافه کرد:

- U-Bahn / Stadtbahn
- Tram
- Bus

## 2. Grain جدول Fact

مهم‌ترین تصمیم طراحی، Grain جدول Fact است.

Grain انتخاب‌شده:

**یک Trip برنامه‌ریزی‌شده، در یک Stop، در یک Service Date مشخص.**

مثال:

اگر یک Trip در تاریخ 2026-07-15 در Köln Hbf توقف داشته باشد، یک رکورد Fact ساخته می‌شود.

اگر همان Trip در Düsseldorf Hbf نیز توقف کند، یک رکورد Fact دیگر ایجاد می‌شود.

اگر همان سرویس در روز دیگری اجرا شود، رکوردهای جدید برای آن Service Date ساخته خواهند شد.

این Grain امکان تحلیل موارد زیر را فراهم می‌کند:

- زمان برنامه‌ریزی‌شده ورود
- زمان برنامه‌ریزی‌شده خروج
- زمان واقعی ورود
- زمان واقعی خروج
- Delay
- Cancellation
- عملکرد Route
- عملکرد Station
- عملکرد بر اساس ساعت
- Delay Propagation

## 3. جدول Fact اصلی

جدول Fact برنامه‌ریزی‌شده:

`dw.FactTripStop`

ستون‌های احتمالی:

- FactTripStopKey
- DateKey
- TripKey
- RouteKey
- StopKey
- OperatorKey
- TransportModeKey
- StopSequence
- PlannedArrivalTime
- PlannedDepartureTime
- ActualArrivalTime
- ActualDepartureTime
- ArrivalDelaySeconds
- DepartureDelaySeconds
- IsCancelled
- IsOnTime
- IsSeverelyDelayed

تا زمانی که داده Realtime یا Historical Actual Performance وارد پروژه نشده، ستون‌های Actual می‌توانند NULL باقی بمانند.

## 4. Dimension تاریخ

جدول:

`dw.DimDate`

این Dimension برای Filtering و Trend Analysis استفاده می‌شود.

Attributeهای احتمالی:

- DateKey
- FullDate
- Year
- Quarter
- Month
- MonthName
- WeekOfYear
- DayOfMonth
- DayOfWeek
- DayName
- IsWeekend

در آینده می‌توان Attributeهای مخصوص NRW را نیز اضافه کرد:

- PublicHoliday
- SchoolHoliday
- HolidayName

## 5. Dimension زمان

جدول:

`dw.DimTime`

این Dimension امکان تحلیل بر اساس موارد زیر را فراهم می‌کند:

- ساعت
- دقیقه
- Morning Peak
- Evening Peak
- Off-Peak

Attributeهای احتمالی:

- TimeKey
- Hour
- Minute
- TimeLabel
- TimePeriod
- IsPeakHour

## 6. Dimension خطوط

جدول:

`dw.DimRoute`

این Dimension اطلاعات خطوط حمل‌ونقل را نگهداری می‌کند.

Attributeهای احتمالی:

- RouteKey
- RouteId
- RouteShortName
- RouteLongName
- RouteType
- RouteColor
- TransportMode
- OperatorName

مثال:

- RE 1
- RB 48
- S 11

فیلد خام GTFS یعنی `route_type` به‌تنهایی برای تشخیص تمام دسته‌بندی‌های Business کافی نیست.

بنابراین در Transformation Layer منطق Classification اضافی ایجاد خواهد شد.

## 7. Dimension سفر

جدول:

`dw.DimTrip`

این Dimension یک Scheduled Journey را نمایش می‌دهد.

Attributeهای احتمالی:

- TripKey
- TripId
- RouteKey
- ServiceId
- TripHeadsign
- TripShortName
- DirectionId
- ShapeId

با استفاده از این Dimension می‌توان تمام Stopهای مربوط به یک Trip را با یکدیگر تحلیل کرد.

## 8. Dimension ایستگاه

جدول:

`dw.DimStop`

Attributeهای احتمالی:

- StopKey
- StopId
- StopName
- Latitude
- Longitude
- LocationType
- ParentStation
- PlatformCode
- NvbwHstDhid

در مرحله Transformation ممکن است تفاوت بین موارد زیر مشخص شود:

- Station
- Platform
- Stop Position

این موضوع مهم است، چون در GTFS ممکن است چند Stop مختلف متعلق به یک ایستگاه فیزیکی باشند.

## 9. Dimension اپراتور

جدول:

`dw.DimOperator`

Attributeهای احتمالی:

- OperatorKey
- SourceAgencyId
- OperatorName
- OperatorGroup
- TransportRegion

داده خام `agency.txt` همیشه یک تعریف Business کاملاً تمیز و یک‌به‌یک از Operator ارائه نمی‌دهد.

به همین دلیل، Normalization اپراتورها در لایه `wrk` انجام خواهد شد.

## 10. Dimension نوع حمل‌ونقل

جدول:

`dw.DimTransportMode`

مقادیر احتمالی:

- RE
- RB
- S-Bahn
- U-Bahn / Stadtbahn
- Tram
- Bus

در فاز اول تمرکز اصلی روی:

- RE
- RB
- S-Bahn

خواهد بود.

این Dimension یک Classification قابل فهم برای Business فراهم می‌کند که مستقل از `route_type` خام GTFS است.

## 11. تولید Service Date

در GTFS برای هر Trip و هر تاریخ فعال، یک رکورد مستقیم وجود ندارد.

فعال بودن سرویس از این فایل‌ها محاسبه می‌شود:

- `calendar.txt`
- `calendar_dates.txt`

بنابراین قبل از Load جدول Fact باید Service Dateهای واقعی تولید شوند.

Transformation برنامه‌ریزی‌شده:

`calendar + calendar_dates → wrk.ServiceDates`

این فرایند باید:

- قوانین روزهای هفته را Expand کند
- StartDate و EndDate را رعایت کند
- Exception Dateهای اضافه‌شده را وارد کند
- Exception Dateهای حذف‌شده را حذف کند

خروجی مشخص می‌کند هر `service_id` در چه تاریخ‌هایی واقعاً فعال است.

## 12. مدیریت زمان GTFS

یکی از تصمیم‌های فنی مهم پروژه مربوط به GTFS Time است.

GTFS اجازه می‌دهد ساعت از `24:00:00` بیشتر باشد.

مثال:

`25:15:00`

یعنی ساعت 01:15 روز بعد، اما همچنان متعلق به Service Day قبلی است.

SQL Server نوع `TIME` چنین مقداری را قبول نمی‌کند.

بنابراین در Staging Layer مقادیر Arrival و Departure به شکل زیر ذخیره شده‌اند:

`VARCHAR(8)`

در Transformation Layer این مقادیر بعداً به ساختار مناسب برای تحلیل تبدیل خواهند شد، در حالی که ارتباط با Service Date حفظ می‌شود.

این تصمیم از خراب شدن اطلاعات سرویس‌های شبانه جلوگیری می‌کند.

## 13. Surrogate Key

Dimensionهای نهایی از Integer Surrogate Key استفاده خواهند کرد.

مثال:

- RouteKey
- StopKey
- TripKey
- OperatorKey
- TransportModeKey

شناسه‌های اصلی GTFS نیز به‌عنوان Business Key حفظ خواهند شد.

مزایای این طراحی:

- روابط پایدارتر
- Performance بهتر در Power BI
- مستقل شدن Data Warehouse از فرمت شناسه‌های Source
- امکان اضافه کردن منابع داده جدید در آینده

## 14. ساختار Star Schema

مدل مفهومی:

```text id="p7d0x2"
                    DimDate
                       |
                       |
DimRoute ---- FactTripStop ---- DimStop
                       |
                       |
                    DimTrip
                       |
                DimOperator
                       |
              DimTransportMode
```

ممکن است در پیاده‌سازی نهایی برخی روابط تغییر کنند، اما هدف حفظ یک مدل ساده و تحلیلی مناسب Power BI است.

## 15. داده Actual Performance در آینده

نسخه اول Data Warehouse عمدتاً بر Scheduled GTFS Data متکی است.

در آینده با اضافه شدن داده Realtime یا Historical Operational Data، ستون‌هایی مانند موارد زیر به Fact اضافه خواهند شد:

- Actual Arrival
- Actual Departure
- Delay Seconds
- Cancellation Status

در نتیجه محاسبه KPIهای زیر ممکن می‌شود:

- Punctuality %
- Average Delay
- Severe Delay %
- Cancellation Rate
- Reliability Score
- Delay Propagation

## 16. اصل طراحی

تا حد امکان، Business Logic اصلی باید در SQL Transformation Layer و Data Warehouse متمرکز باشد.

Power BI بیشتر برای این موارد استفاده می‌شود:

- Measures
- Visualization
- Filtering
- Business Reporting

و نه برای بازسازی Transformationهای پیچیده Source.

این جداسازی باعث می‌شود پروژه:

- Maintainableتر
- شفاف‌تر
- قابل تکرارتر
- حرفه‌ای‌تر

باشد.
