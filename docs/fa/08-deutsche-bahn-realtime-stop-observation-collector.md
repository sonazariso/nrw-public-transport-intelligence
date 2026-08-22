## 8. DB Realtime Stop Observation Collector

### هدف این مرحله

در این مرحله اتصال اولیه به Deutsche Bahn Timetables API به یک Collector واقعی برای ذخیره Snapshotهای وضعیت قطار در SQL Server تبدیل شد.

هدف این بود که برای هر توقف قطار در یک ایستگاه، اطلاعات زیر در یک رکورد ذخیره شود:

- Planned Arrival
- Changed Arrival
- Arrival Delay
- Arrival Cancellation
- Planned Departure
- Changed Departure
- Departure Delay
- Departure Cancellation
- Planned Platform
- Changed Platform
- Capture Time

ایستگاه مورد استفاده برای تست اولیه:

```text
Köln Hbf
EVA: 8000207
```

---

## 8.1 ایجاد جدول Staging

جدول زیر برای ذخیره Snapshotهای دریافتی از DB API ایجاد شد:

```sql
stg.DbRealtimeStopObservation
```

ساختار جدول شامل 16 ستون است:

```text
ObservationKey
DbEventId
StationEva
LineName
TrainName
PlannedArrival
ChangedArrival
ArrivalDelayMinutes
IsArrivalCancelled
PlannedDeparture
ChangedDeparture
DepartureDelayMinutes
IsDepartureCancelled
PlannedPlatform
ChangedPlatform
CapturedAt
```

`ObservationKey` کلید داخلی SQL Server است.

`DbEventId` شناسه Event دریافتی از Deutsche Bahn API است.

`CapturedAt` زمان اجرای Collector و ثبت Snapshot را مشخص می‌کند.

این جدول برای نگهداری **Observation History** طراحی شده است، بنابراین اجرای بعدی Collector قرار نیست رکورد قبلی را Update کند. هر اجرا می‌تواند Snapshot جدیدی از همان `DbEventId` با `CapturedAt` جدید ثبت کند.

---

## 8.2 Indexها

برای پشتیبانی از تحلیل‌های بعدی، Index روی ترکیب‌های زیر ایجاد شد:

```text
(DbEventId, CapturedAt)
```

و:

```text
(StationEva, CapturedAt)
```

این Indexها بعداً برای بررسی تغییرات یک Event در طول زمان و همچنین تحلیل داده‌های یک ایستگاه مفید خواهند بود.

---

## 8.3 APIهای مورد استفاده

دو endpoint اصلی Deutsche Bahn Timetables API استفاده شدند.

### Plan

```text
/plan/{eva}/{date}/{hour}
```

این endpoint اطلاعات برنامه‌ریزی‌شده قطارها برای یک ساعت مشخص را برمی‌گرداند.

فیلدهای مهم:

```text
pt = Planned Time
pp = Planned Platform
```

### Full Changes

```text
/fchg/{eva}
```

این endpoint آخرین تغییرات مربوط به Eventهای ایستگاه را برمی‌گرداند.

فیلدهای مهم:

```text
ct = Changed Time
cp = Changed Platform
cs = Status
```

برای Cancellation مقدار زیر مشاهده شد:

```text
cs = "c"
```

---

## 8.4 تست API برای Köln Hbf

API برای ایستگاه Köln Hbf با EVA زیر تست شد:

```text
8000207
```

در یکی از تست‌ها نتایج زیر دریافت شد:

```text
Plan stops:   63
Change stops: 945
```

بیشتر بودن تعداد `/fchg` طبیعی است، زیرا `/plan` فقط Eventهای ساعت درخواست‌شده را برمی‌گرداند ولی `/fchg` تغییرات جاری بیشتری برای ایستگاه در اختیار قرار می‌دهد.

---

## 8.5 Matching بین Plan و Changes

Eventهای `/plan` و `/fchg` بر اساس `id` به یکدیگر Match شدند.

این `id` در SQL Server به صورت:

```text
DbEventId
```

ذخیره می‌شود.

در تست انجام‌شده:

```text
Plan events: 63
Matched:     63
Not matched: 0
```

بنابراین تمام Eventهای Plan در آن Snapshot دارای Event متناظر در `/fchg` بودند.

---

## 8.6 تبدیل زمان Deutsche Bahn

زمان‌های API در قالب زیر دریافت می‌شوند:

```text
yyMMddHHmm
```

مثال:

```text
2608221303
```

معادل است با:

```text
2026-08-22 13:03
```

برای تبدیل این مقدار در PowerShell Function زیر ایجاد شد:

```powershell
function Convert-DbTime {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return [datetime]::ParseExact(
        $Value,
        "yyMMddHHmm",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}
```

---

## 8.7 محاسبه Delay

Delay فقط زمانی محاسبه می‌شود که هم Planned Time و هم Changed Time وجود داشته باشند.

مثال:

```text
PlannedArrival = 13:03
ChangedArrival = 13:04
```

نتیجه:

```text
ArrivalDelayMinutes = 1
```

منطق PowerShell:

```powershell
if ($plannedArrival -and $changedArrival) {
    [int](($changedArrival - $plannedArrival).TotalMinutes)
}
else {
    $null
}
```

این تفاوت مهم است:

```text
0    = قطار Delay ندارد
NULL = اطلاعات کافی برای محاسبه Delay وجود ندارد
```

بنابراین مقدار `NULL` عمداً حفظ می‌شود.

---

## 8.8 Cancellation

Cancellation برای Arrival و Departure به صورت مستقل بررسی می‌شود.

Arrival:

```powershell
$changeStop.ar.cs -eq "c"
```

Departure:

```powershell
$changeStop.dp.cs -eq "c"
```

در داده تست‌شده Cancellation واقعی مشاهده شد.

همچنین در بعضی Cancellationها مقدار Changed Time وجود نداشت. این رفتار طبیعی است و Changed Time مصنوعی تولید نشد.

---

## 8.9 Platform

Planned Platform ابتدا از Arrival گرفته می‌شود:

```text
ar.pp
```

اگر وجود نداشته باشد، Departure بررسی می‌شود:

```text
dp.pp
```

برای Changed Platform نیز به همین صورت:

```text
ar.cp
```

و سپس:

```text
dp.cp
```

در Staging فقط مقدار خام Planned و Changed ذخیره می‌شود.

`PlatformChanged` به‌صورت ستون جداگانه ذخیره نشد، زیرا بعداً قابل محاسبه است:

```sql
CASE
    WHEN PlannedPlatform IS NOT NULL
     AND ChangedPlatform IS NOT NULL
     AND PlannedPlatform <> ChangedPlatform
    THEN 1
    ELSE 0
END
```

---

## 8.10 Full Snapshot

برای هر DB Event یک Snapshot کامل ساخته شد که شامل داده‌های زیر است:

```text
DbEventId
StationEva
LineName
TrainName
PlannedArrival
ChangedArrival
ArrivalDelayMinutes
IsArrivalCancelled
PlannedDeparture
ChangedDeparture
DepartureDelayMinutes
IsDepartureCancelled
PlannedPlatform
ChangedPlatform
CapturedAt
```

---

## 8.11 SQL NULL Handling

برای ارسال مقدارهای nullable از PowerShell به SQL Server، Function زیر استفاده شد:

```powershell
function DbValue {
    param($Value)

    if ($null -eq $Value) {
        return [DBNull]::Value
    }

    return $Value
}
```

این Function برای ستون‌هایی مانند موارد زیر ضروری است:

```text
ChangedArrival
ChangedDeparture
ArrivalDelayMinutes
DepartureDelayMinutes
ChangedPlatform
```

---

## 8.12 تست INSERT

قبل از تست Full Collector، داده‌های Arrival-only قبلی حذف شدند:

```sql
TRUNCATE TABLE stg.DbRealtimeStopObservation;
```

سپس Full Snapshot Collector اجرا شد.

نتیجه:

```text
Inserted snapshots: 63
```

---

## 8.13 Validation

نتایج PowerShell:

```text
TotalSnapshots        : 63
WithArrival           : 59
WithDeparture         : 57
ArrivalCancelled      : 2
DepartureCancelled    : 2
WithChangedPlatform   : 12
PlatformChanged       : 12
```

همین نتایج مستقیماً در SQL Server نیز تأیید شدند:

```text
TotalRows             : 63
WithArrival           : 59
WithDeparture         : 57
ArrivalCancelled      : 2
DepartureCancelled    : 2
WithChangedPlatform   : 12
PlatformChanged       : 12
```

این تطابق نشان داد که مسیر زیر صحیح کار می‌کند:

```text
Deutsche Bahn API
        ↓
PowerShell Collector
        ↓
Event Matching
        ↓
Full Snapshot
        ↓
SQL Server Staging
```

---

## 8.14 بررسی داده واقعی

داده‌های ذخیره‌شده شامل Delayهای واقعی مانند:

```text
1 minute
2 minutes
3 minutes
7 minutes
15 minutes
```

بودند.

همچنین موارد زیر مشاهده شدند:

```text
Arrival Cancellation
Departure Cancellation
Platform Change
Arrival-only events
Departure-only events
NULL Changed Time for cancelled events
```

همه این وضعیت‌ها به‌درستی بدون تولید داده مصنوعی ذخیره شدند.

---

## وضعیت فعلی

نسخه آزمایشی Full Collector برای Köln Hbf با موفقیت تأیید شده است.

مرحله بعد:

ساخت یک فایل PowerShell مستقل و قابل اجرای مجدد، مثلاً:

```text
DbRealtimeCollector.ps1
```

که به‌صورت خودکار:

```text
Current Hour Plan
+
Next Hour Plan
+
fchg
↓
Deduplication
↓
Matching
↓
Full Snapshot creation
↓
Append to stg.DbRealtimeStopObservation
```

را انجام دهد.

از این مرحله به بعد دیگر `TRUNCATE` انجام نمی‌شود، زیرا هدف جمع‌آوری تاریخچه Snapshotها در طول زمان است.
