# ۹. Collector نهایی Realtime، بارگذاری DW و عملیات

## ۹.۱ محدوده این Checkpoint

این فصل مستقیماً ادامه فصل ۸ است و فقط کارهای انجام‌شده بعد از Full Collector آزمایشی را تا تاریخ **2026-08-22** ثبت می‌کند.

پیاده‌سازی فعلی برای ایستگاه پایلوت Köln Hbf به‌صورت production-like اجرا و تأیید شده است، اما هنوز یک سرویس چندایستگاهی برای کل NRW نیست.

## ۹.۲ جریان نهایی Collector

فایل قابل اجرای مجدد `DbRealtimeCollector.ps1` کل زنجیره را انجام می‌دهد:

```text
DB Timetables API
  -> /plan ساعت جاری + /plan ساعت بعد + /fchg
  -> حذف DbEventIdهای تکراری
  -> Match داده Planned و Changed
  -> Append کردن Snapshot کامل در stg.DbRealtimeStopObservation
  -> انتخاب آخرین Observation هر Event
  -> Strong Match بین DB و GTFS Trip Stop
  -> ساخت wrk.vDbRealtimeStopPerformanceLoadSource
  -> UPDATE رکوردهای موجود و INSERT رکوردهای جدید
  -> dw.FactRealtimeStopPerformance
```

خواندن هم‌زمان ساعت جاری و ساعت بعد، شکاف اطراف مرز ساعت را از بین می‌برد. چون این دو بازه می‌توانند هم‌پوشانی داشته باشند، Deduplication بر اساس `DbEventId` ضروری است.

Staging در اجرای عادی append-only باقی می‌ماند. تکرار Observationها عمدی است و تاریخچه تغییر Delay، Cancellation و Platform را حفظ می‌کند.

## ۹.۳ Strong Match و Grain جدول Fact

فقط Matchهای قابل اتکا وارد Realtime Fact می‌شوند. در Load Source تأییدشده، رابطه `DbEventId` و `FactTripStopKey` یک‌به‌یک است.

جدول `dw.FactRealtimeStopPerformance` برای هر زوج DB Event / GTFS Trip Stop یک رکورد جاری نگه می‌دارد و شامل آخرین Observation، اولین و آخرین زمان Capture، تعداد Observationها، Delayها، Cancellation، Platform و Match Metadata است.

Loader از هر دو جهت رابطه محافظت می‌کند:

- یک `DbEventId` موجود نباید به `FactTripStopKey` دیگری منتقل شود؛
- یک `FactTripStopKey` موجود نباید به `DbEventId` دیگری منتقل شود.

در صورت Conflict، Load با خطا متوقف می‌شود تا Grain جدول Fact به‌صورت خاموش خراب نشود.

## ۹.۴ DW Upsert تکرارپذیر

Stored Procedure با نام `dw.usp_LoadFactRealtimeStopPerformance` فقط Eventهایی را Update می‌کند که Latest Observation آن‌ها جلو رفته باشد و فقط Eventهای جدید را Insert می‌کند. اجرای دوباره بدون Source جدید، صفر Update و صفر Insert تولید می‌کند.

آخرین Validation همگام‌سازی:

```text
SourceRows    = 133
FactRows      = 133
MatchedRows   = 133
OutOfSyncRows = 0
```

بنابراین در Checkpoint فعلی، Load Source و Realtime Fact کاملاً همگام بوده‌اند.

## ۹.۵ بهینه‌سازی Performance Loader

نسخه اولیه Procedure، View پیچیده Source را چند بار محاسبه می‌کرد و حدود 59.7 ثانیه زمان می‌برد. نسخه نهایی View را فقط یک بار داخل `#Source` materialize می‌کند، برای `DbEventId` و `FactTripStopKey` ایندکس Unique می‌سازد و سپس Safety Check و Upsert را در یک Transaction کوتاه انجام می‌دهد.

Benchmark تأییدشده:

```text
قبل: حدود 59.7 ثانیه
بعد: حدود 1.1 ثانیه
```

ساخت `#Source` قبل از Transaction انجام می‌شود تا محاسبات نسبتاً سنگین Matching مدت Lockهای جدول Fact را افزایش ندهند.

## ۹.۶ Wrapper عملیاتی و Logging

فایل `RunDbRealtimeCollector.ps1`، Collector را با Stop-on-error اجرا کرده و برای هر Run یک Log زمان‌دار در مسیر زیر می‌سازد:

```text
C:\NRWTransport\Collector\Logs
```

Wrapper زمان شروع، خروجی Collector، پایان موفق یا خطای منجر به شکست را ثبت می‌کند. اجرای آن در PowerShell مستقل با `-NoProfile` تأیید شد؛ بنابراین Scheduled Run به Session تعاملی قبلی وابسته نیست.

Credentialهای API باید خارج از Source Control باقی بمانند و نباید داخل Repository، مستندات یا Logها Commit شوند.

## ۹.۷ Windows Task Scheduler

Task با نام `NRW DB Realtime Collector` هر ۱۵ دقیقه Wrapper را اجرا می‌کند. تنظیمات عملیاتی تأییدشده:

- تکرار هر ۱۵ دقیقه به‌صورت نامحدود؛
- اجرا حتی زمانی که User وارد Windows نشده است؛
- Start in برابر `C:\NRWTransport\Collector`؛
- اجرای Run ازدست‌رفته در اولین فرصت؛
- جلوگیری از شروع Instance جدید اگر Run قبلی هنوز فعال است؛
- توقف Run غیرعادی پس از حداقل Limit در دسترس، یعنی یک ساعت.

اجرای خودکار در 2026-08-22 با نتیجه `0x0` کامل شد، Log جدید ساخت، 71 Snapshot وارد کرد، 30 Fact Row را Update کرد و تعداد کل Factها را به 133 رساند.

## ۹.۸ حجم مشاهده‌شده و تصمیم Retention

اولین نمونه History تأییدشده:

```text
Observations     = 1,097
Distinct events = 313
Capture period  = 2026-08-22 13:42:44 تا 21:50:18
Table size      = 0.52 MB reserved / 0.41 MB used
```

با حدود 71 ردیف در هر Run و 96 Run در روز، Köln Hbf تقریباً 6,800 Observation در روز تولید می‌کند. فعلاً Cleanup فعال نشده، چون Raw History برای اعتبارسنجی نیازهای تحلیلی لازم است.

Retention Target برای پیاده‌سازی آینده:

```text
stg.DbRealtimeStopObservation   180 روز
Collector logs                  30 روز
dw.FactRealtimeStopPerformance بدون حذف زمان‌بندی‌شده
```

تا زمانی که تمام History لازم برای Power BI در یک ساختار تحلیلی مناسب حفظ نشده است، Raw Cleanup نباید فعال شود.

## ۹.۹ وضعیت پروژه در 2026-08-22

موارد تکمیل و تأییدشده:

- جمع‌آوری Köln Hbf برای ساعت جاری و ساعت بعد؛
- حذف Eventهای تکراری ناشی از هم‌پوشانی دو بازه؛
- تاریخچه append-only برای Realtime Observation؛
- ثبت Delay، Cancellation و Platform؛
- Strong Match بین DB و GTFS؛
- DW Upsert تکرارپذیر و محافظت‌شده در برابر Conflict؛
- کاهش زمان Loader از حدود یک دقیقه به حدود یک ثانیه؛
- اجرای مستقل Wrapper و ساخت Log زمان‌دار؛
- اجرای خودکار هر ۱۵ دقیقه با Windows Task Scheduler.

موارد هنوز پیاده‌سازی‌نشده:

- Configuration دیتابیسی برای چند ایستگاه NRW؛
- Cleanup خودکار Staging و Log؛
- مدل تحلیلی تاریخی فراتر از Latest-state Realtime Fact؛
- داشبوردهای Performance در Power BI.

## ۹.۱۰ نقطه شروع بعدی

مرحله بعد ساخت یک Configuration مانند `cfg.DbRealtimeStation` و خارج‌کردن EVA/GTFS Mapping از PowerShell است. ابتدا Köln Hbf باید بدون تغییر نتیجه Collector به این Configuration منتقل شود؛ سپس ایستگاه‌های دیگر NRW به‌تدریج اضافه شوند.

پس از پایدارشدن Multi-station Collection، Retention Jobها و مدل تاریخی مناسب Power BI پیاده‌سازی می‌شوند.
