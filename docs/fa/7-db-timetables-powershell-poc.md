# اتصال DB Timetables API به پروژه با PowerShell

## پروژه NRW Rail Performance Analytics

این سند روند اتصال پروژه تحلیل عملکرد حمل‌ونقل ریلی NRW به API رسمی Deutsche Bahn را توضیح می‌دهد؛ از ساخت Application در سایت DB تا دریافت داده، خواندن XML، استخراج اطلاعات و Match کردن زمان برنامه‌ریزی‌شده با زمان تغییرکرده.

هدف این بخش این بود که Data Warehouse فعلی که بر اساس **Soll-Fahrplandaten / Scheduled Data** ساخته شده است، در آینده بتواند اطلاعات واقعی عملیاتی را نیز دریافت کند و شاخص‌هایی مانند موارد زیر را محاسبه کند:

- تأخیر ورود
- تأخیر خروج
- تغییر سکو
- لغو قطار
- Punctuality
- مقایسه Scheduled و Actual

---

# 1. مسئله چه بود؟

در فاز اول پروژه، Data Warehouse با داده GTFS مربوط به NRW ساخته شد.

Scope فعلی شامل:

```text
RE
RB
S-Bahn
```

است.

از GTFS اطلاعاتی مانند این موارد داریم:

```text
Service Date
Route
Station
Stop Sequence
Scheduled Arrival
Scheduled Departure
```

اما GTFS برنامه حرکت به ما نمی‌گوید:

```text
آیا قطار واقعاً دیر رسید؟
چند دقیقه تأخیر داشت؟
آیا سکو تغییر کرد؟
آیا قطار لغو شد؟
کدام خط بیشترین تأخیر را دارد؟
کدام ایستگاه عملکرد ضعیف‌تری دارد؟
```

برای پاسخ دادن به این سؤال‌ها به یک منبع **Actual / Changed operational data** نیاز داشتیم.

برای Proof of Concept، API رسمی Deutsche Bahn یعنی:

```text
DB Timetables API
```

انتخاب شد.

---

# 2. چرا DB Timetables API؟

دو بخش این API برای پروژه ما بسیار مهم هستند.

اول:

```text
/plan
```

که اطلاعات برنامه‌ریزی‌شده یا Planned/Soll را ارائه می‌کند.

دوم:

```text
/fchg
```

که تغییرات جاری نسبت به برنامه را ارائه می‌کند.

بنابراین می‌توانیم:

```text
Planned Data
    +
Changed Data
    ↓
Compare
    ↓
Delay
```

داشته باشیم.

مثلاً:

```text
Planned Arrival = 11:15
Changed Arrival = 11:23
Delay           = 8 minutes
```

این دقیقاً پایه‌ای است که برای Performance Analytics نیاز داریم.

---

# 3. ساخت Application در DB API Marketplace

ابتدا در سایت DB API Marketplace ثبت‌نام کردیم.

سپس یک Application ایجاد شد.

نام مناسب برای Application می‌تواند مثلاً این باشد:

```text
NRW Rail Performance Analytics
```

بعد Application به محصول:

```text
Timetables API
```

متصل / Subscribe شد.

برای استفاده از API دو Credential در اختیار ما قرار گرفت:

```text
DB-Client-ID
DB-Api-Key
```

## نکته امنیتی بسیار مهم

این مقادیر نباید:

- داخل Git قرار بگیرند
- داخل README نوشته شوند
- در Screenshot دیده شوند
- داخل SQL Script قرار بگیرند
- داخل Source Code عمومی Hard-code شوند

برای Proof of Concept آنها را فقط به‌صورت Variable داخل PowerShell نگه داشتیم:

```powershell
$clientId = "YOUR_CLIENT_ID"
$apiKey   = "YOUR_API_KEY"
```

سپس Header مربوط به Authentication ساخته شد:

```powershell
$headers = @{
    "DB-Client-ID" = $clientId
    "DB-Api-Key"   = $apiKey
}
```

از همین `$headers` در درخواست‌های بعدی استفاده کردیم.

---

# 4. چرا از PowerShell استفاده کردیم؟

در این مرحله هدف ما هنوز ساخت Application نهایی برای Data Ingestion نبود.

ابتدا می‌خواستیم API واقعی را بشناسیم.

PowerShell برای این کار بسیار مناسب بود چون بدون ساخت Project جدید توانستیم:

- HTTP Request ارسال کنیم
- Authentication انجام دهیم
- پاسخ Raw API را ببینیم
- XML را Parse کنیم
- فیلدهای API را بررسی کنیم
- Identifierها را شناسایی کنیم
- Plan و Change را Match کنیم
- Delay را آزمایش کنیم

اصل مهم این مرحله این بود:

> ابتدا داده واقعی Source را بررسی کن، سپس Tableهای Data Warehouse را طراحی کن.

اگر قبل از دیدن پاسخ واقعی API جدول Actual Data را طراحی می‌کردیم، احتمال زیادی داشت Structure را بر اساس حدس بسازیم.

---

# 5. پیدا کردن EVA Number ایستگاه Köln Hbf

DB برای شناسایی ایستگاه‌ها از یک Identifier به نام:

```text
EVA Number
```

استفاده می‌کند.

ما برای Proof of Concept ایستگاه زیر را انتخاب کردیم:

```text
Köln Hbf
```

ابتدا نام ایستگاه را به API دادیم تا EVA Number رسمی آن را پیدا کنیم.

در PowerShell:

```powershell
$response = Invoke-WebRequest `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/station/K%C3%B6ln%20Hbf" `
  -Headers $headers
```

بعد پاسخ را دیدیم:

```powershell
$response.Content
```

API چیزی شبیه این برگرداند:

```xml
<station
    name="Köln Hbf"
    eva="8000207"
    ...
/>
```

پس:

```text
Station = Köln Hbf
EVA     = 8000207
```

این عدد در درخواست‌های بعدی استفاده شد.

---

# 6. هشدار اولیه PowerShell

اولین بار هنگام استفاده از:

```powershell
Invoke-WebRequest
```

Windows PowerShell یک Security Warning نشان داد.

علت آن Parsing محتوای Web Page بود.

در درخواست‌های بعدی از:

```powershell
-UseBasicParsing
```

استفاده کردیم.

مثلاً:

```powershell
Invoke-WebRequest `
    -UseBasicParsing `
    ...
```

در نتیجه دیگر Parsing غیرضروری صفحه انجام نمی‌شود.

---

# 7. دریافت Planned Timetable

بعد از پیدا کردن EVA، هدف این بود که برنامه حرکت قطارهای Köln Hbf را بگیریم.

EVA را داخل Variable قرار دادیم:

```powershell
$eva = "8000207"
```

Endpoint مربوط به Plan علاوه بر EVA، تاریخ و ساعت نیز لازم دارد.

برای Proof of Concept:

```powershell
$date = "260822"
$hour = "11"
```

فرمت تاریخ:

```text
yyMMdd
```

است.

پس:

```text
260822
```

یعنی:

```text
22.08.2026
```

و:

```text
11
```

یعنی بازه ساعت 11.

Request:

```powershell
$planResponse = Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/plan/$eva/$date/$hour" `
  -Headers $headers
```

بعد Raw Response را دیدیم:

```powershell
$planResponse.Content
```

پاسخ بسیار بزرگ بود و شامل انواع سرویس‌ها بود:

```text
S-Bahn
RE
RB
ICE
FLX
...
```

این نتیجه ثابت کرد endpoint `/plan` به‌درستی کار می‌کند.

---

# 8. تبدیل پاسخ Plan به XML Object

چون پاسخ API XML بود، به‌جای خواندن صدها خط متن آن را Parse کردیم:

```powershell
[xml]$planXml = $planResponse.Content
```

بعد فقط سه رکورد اول را مشاهده کردیم:

```powershell
$planXml.timetable.s |
    Select-Object -First 3 |
    Format-List *
```

به این ترتیب Structure داده بسیار قابل فهم‌تر شد.

یک Structure ساده‌شده شبیه این است:

```xml
<s id="...">

    <tl
        c="S"
        n="32170"
    />

    <ar
        pt="2608221146"
        pp="10"
        l="S11"
    />

    <dp
        pt="2608221147"
        pp="10"
        l="S11"
    />

</s>
```

---

# 9. معنی فیلدهای مهم Plan

## `s.id`

یکی از مهم‌ترین Fieldهای کل API است.

مثلاً:

```text
2958834342628665585-2608220720-5
```

این ID بعداً برای Match کردن Plan و Change استفاده شد.

یعنی:

```text
Plan.ID = Change.ID
```

---

## `tl`

اطلاعات Train را نگه می‌دارد.

مثلاً:

```xml
<tl c="S" n="32170" />
```

معنی:

```text
c = Train Category
n = Train Number
```

مثلاً:

```text
c = S
```

نشان‌دهنده S-Bahn است.

---

## `ar`

مربوط به Arrival است.

مثلاً:

```xml
<ar
    pt="2608221115"
    pp="4"
    fb="EUR 9411"
/>
```

مهم‌ترین Attributeها:

```text
pt = Planned Time
pp = Planned Platform
```

---

## `dp`

اطلاعات Departure را نگه می‌دارد.

مانند Arrival می‌تواند دارای:

```text
pt = Planned Departure Time
pp = Planned Platform
```

باشد.

---

## `l`

Line را مشخص می‌کند.

مثلاً:

```text
S11
RE7
RB25
```

این Field برای پروژه ما مهم است چون Data Warehouse فعلی نیز روی RE/RB/S-Bahn تمرکز دارد.

---

## `ppth`

Planned Path است.

یعنی لیستی از Stationهایی که طبق برنامه قبل یا بعد از این Station در مسیر قرار دارند.

---

# 10. دریافت Changed Data

بعد از اطمینان از Plan، مرحله بعد گرفتن تغییرات واقعی بود.

Endpoint:

```text
/fchg/{EVA}
```

برای Köln Hbf:

```text
/fchg/8000207
```

در PowerShell:

```powershell
$changeResponse = Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/fchg/$eva" `
  -Headers $headers
```

بعد XML را Parse کردیم:

```powershell
[xml]$changeXml = $changeResponse.Content
```

برای مشاهده چند رکورد:

```powershell
$changeXml.timetable.s |
    Select-Object -First 3 |
    Format-List *
```

---

# 11. فیلد Changed Time

در یکی از رکوردها دیدیم:

```xml
<ar ct="2608221123" />
```

اینجا:

```text
ct
```

یعنی Changed Time.

مقدار:

```text
2608221123
```

برابر است با:

```text
22.08.2026 11:23
```

بنابراین تفاوت اصلی:

```text
pt = Planned Time
ct = Changed Time
```

است.

---

# 12. پیدا کردن یک رکورد دارای Changed Arrival

برای پیدا کردن اولین رکوردی که Changed Arrival دارد، نوشتیم:

```powershell
$changed = $changeXml.timetable.s |
    Where-Object { $_.ar.ct } |
    Select-Object -First 1
```

ID آن را دیدیم:

```powershell
$changed.id
```

و XML Arrival آن را:

```powershell
$changed.ar.OuterXml
```

نتیجه:

```xml
<ar ct="2608221123" />
```

ID این رکورد:

```text
2958834342628665585-2608220720-5
```

بود.

---

# 13. Match کردن Plan و Change

این مهم‌ترین قسمت Proof of Concept بود.

ابتدا ID مربوط به Changed Data را ذخیره کردیم:

```powershell
$id = $changed.id
```

بعد در `planXml` دنبال همان ID گشتیم:

```powershell
$planned = $planXml.timetable.s |
    Where-Object { $_.id -eq $id } |
    Select-Object -First 1
```

بعد بررسی کردیم:

```powershell
$planned.id
```

و Plan Arrival را نمایش دادیم:

```powershell
$planned.ar.OuterXml
```

همچنین Change Arrival:

```powershell
$changed.ar.OuterXml
```

نتیجه Plan چیزی شبیه این بود:

```xml
<ar
    pt="2608221115"
    pp="4"
    fb="EUR 9411"
    ...
/>
```

و Change:

```xml
<ar ct="2608221123" />
```

در نتیجه:

```text
Planned Arrival = 11:15
Changed Arrival = 11:23
```

پس:

```text
Arrival Delay = 8 minutes
```

این اولین بار بود که در پروژه با داده واقعی DB، Delay را از روی Planned و Changed Data اثبات کردیم.

---

# 14. منطق اصلی Match

منطق اصلی به شکل زیر است:

```text
DB /plan
   │
   │ ID
   ▼
Match
   ▲
   │ ID
   │
DB /fchg
```

یعنی:

```text
plannedStop.id = changedStop.id
```

سپس:

```text
ArrivalDelay =
ChangedArrival
-
PlannedArrival
```

و در آینده:

```text
DepartureDelay =
ChangedDeparture
-
PlannedDeparture
```

---

# 15. تبدیل Timestamp به DateTime

DB Timestamp را به صورت Compact برمی‌گرداند.

مثلاً:

```text
2608221115
```

فرمت آن:

```text
yyMMddHHmm
```

است.

در PowerShell می‌توانیم آن را تبدیل کنیم:

```powershell
$plannedArrival = [datetime]::ParseExact(
    $plannedStop.ar.pt,
    "yyMMddHHmm",
    $null
)
```

برای Changed:

```powershell
$changedArrival = [datetime]::ParseExact(
    $changedStop.ar.ct,
    "yyMMddHHmm",
    $null
)
```

بعد اختلاف را محاسبه می‌کنیم:

```powershell
($changedArrival - $plannedArrival).TotalMinutes
```

---

# 16. اسکریپت آماده برای چند رکورد

برای اینکه این کار را فقط برای یک قطار انجام ندهیم، Pattern زیر آماده شد:

```powershell
$results = foreach ($changedStop in $changeXml.timetable.s) {

    $id = $changedStop.id

    $plannedStop = $planXml.timetable.s |
        Where-Object { $_.id -eq $id } |
        Select-Object -First 1

    if ($plannedStop -and $changedStop.ar.ct -and $plannedStop.ar.pt) {

        $plannedArrival = [datetime]::ParseExact(
            $plannedStop.ar.pt,
            "yyMMddHHmm",
            $null
        )

        $changedArrival = [datetime]::ParseExact(
            $changedStop.ar.ct,
            "yyMMddHHmm",
            $null
        )

        [PSCustomObject]@{
            Id                  = $id
            Line                = $plannedStop.ar.l
            Train               = $plannedStop.ar.fb
            PlannedArrival      = $plannedArrival
            ChangedArrival      = $changedArrival
            ArrivalDelayMinutes = [math]::Round(
                ($changedArrival - $plannedArrival).TotalMinutes,
                0
            )
            PlannedPlatform     = $plannedStop.ar.pp
            ChangedPlatform     = $changedStop.ar.cp
        }
    }
}
```

برای نمایش:

```powershell
$results |
    Select-Object -First 10 |
    Format-Table -AutoSize
```

یا:

```powershell
$results |
    Select-Object -First 10 |
    Format-List
```

تا زمان نگارش این مستند، Match یک رکورد واقعی Plan/Change با موفقیت تأیید شده است و اسکریپت بالا گام بعدی برای Generalize کردن همین منطق روی چند Record است.

---

# 17. Mapping فیلدهای API

| Field | معنی |
|---|---|
| `s.id` | شناسه Event / Timetable Stop |
| `s.eva` | شناسه رسمی Station |
| `tl.c` | Train Category |
| `tl.n` | Train Number |
| `ar.pt` | Planned Arrival |
| `ar.ct` | Changed Arrival |
| `ar.pp` | Planned Arrival Platform |
| `ar.cp` | Changed Arrival Platform |
| `ar.l` | Line |
| `ar.fb` | Train/Service Designation |
| `dp.pt` | Planned Departure |
| `dp.ct` | Changed Departure |
| `dp.pp` | Planned Departure Platform |
| `dp.cp` | Changed Departure Platform |
| `ppth` | Planned Path |

نکته مهم:

همه Attributeها در همه رکوردها وجود ندارند.

بنابراین Parser آینده باید وجود یا عدم وجود Field را بررسی کند.

---

# 18. ارتباط این بخش با Data Warehouse فعلی

تا قبل از DB API معماری ما:

```text
NRW GTFS
   ↓
stg
   ↓
wrk
   ↓
dw
   ├── DimDate
   ├── DimRoute
   ├── DimStop
   └── FactTripStop
```

بود.

با DB API یک Source جدید اضافه می‌شود:

```text
DB Timetables API
       ↓
/station
/plan
/fchg
       ↓
PowerShell Exploration
       ↓
Future API Staging
       ↓
Actual / Changed Processing
       ↓
Performance KPIs
```

مدل نهایی در آینده:

```text
GTFS Scheduled Data
        +
DB Operational Data
        ↓
Scheduled vs Actual
        ↓
NRW Rail Performance Analytics
```

خواهد بود.

---

# 19. چرا این قسمت برای مصاحبه مهم است؟

این بخش چند Skill مهم را همزمان نشان می‌دهد:

- کار با External API
- Authentication
- HTTP Request
- PowerShell
- XML Parsing
- Data Discovery
- Data Transformation
- Identifier Matching
- DateTime Conversion
- Business KPI Calculation
- Data Warehouse Integration Thinking

در واقع PowerShell فقط برای گرفتن داده استفاده نشد.

از آن به عنوان یک **Exploration / Prototyping Layer** استفاده شد.

یعنی قبل از اینکه Actual Tables را در SQL Server طراحی کنیم، ابتدا ساختار واقعی API را بررسی کردیم.

---

# 20. توضیح مناسب برای مصاحبه

می‌توان این بخش را در مصاحبه این‌طور توضیح داد:

> من ابتدا Data Warehouse را با داده‌های GTFS برنامه‌ریزی‌شده NRW ساختم، اما متوجه شدم Scheduled Data به‌تنهایی برای Performance Analysis کافی نیست. بنابراین API رسمی Deutsche Bahn را بررسی کردم. قبل از طراحی جدول‌های جدید SQL، با PowerShell یک Proof of Concept ساختم. ابتدا Köln Hbf را به EVA Number تبدیل کردم، سپس با endpoint `/plan` برنامه حرکت را دریافت کردم و پاسخ XML را Parse کردم. بعد با `/fchg` تغییرات عملیاتی را گرفتم. با استفاده از ID مشترک Plan و Change، یک رکورد واقعی را Match کردم. زمان برنامه‌ریزی‌شده ورود 11:15 و Changed Time برابر 11:23 بود و در نتیجه Delay هشت دقیقه محاسبه شد. این Proof of Concept ساختار لازم برای طراحی Actual Data Pipeline را مشخص کرد.

نسخه کوتاه‌تر:

> قبل از طراحی لایه Actual در Data Warehouse، از PowerShell برای Data Discovery روی DB Timetables API استفاده کردم. به این ترتیب API authentication، XML schema، identifier matching و محاسبه Planned-vs-Changed delay را روی داده واقعی Validate کردم.

---

# 21. اصل مهم مهندسی این مرحله

مهم‌ترین درس این قسمت:

> **ساختار دیتابیس را بر اساس حدس در مورد Source خارجی طراحی نکن؛ ابتدا Source واقعی را ببین، Parse کن و Validation انجام بده.**

PowerShell در این پروژه یک ابزار موقت ولی بسیار مهم بین API خارجی و Data Warehouse بود.

به کمک آن قبل از توسعه Pipeline نهایی مطمئن شدیم که:

```text
API قابل دسترس است
↓
Station قابل شناسایی است
↓
Plan قابل دریافت است
↓
Changes قابل دریافت است
↓
Recordها قابل Match هستند
↓
Delay قابل محاسبه است
```

و بنابراین مرحله بعدی می‌تواند با اطمینان بیشتری روی طراحی **Actual/Realtime ingestion layer در SQL Server** متمرکز شود.
