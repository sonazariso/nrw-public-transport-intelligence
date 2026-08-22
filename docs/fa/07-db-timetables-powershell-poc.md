# اتصال DB Timetables API به پروژه با PowerShell

## پروژه NRW Rail Performance Analytics

این سند روند اتصال پروژه **NRW Rail Performance Analytics** به API رسمی Deutsche Bahn را توضیح می‌دهد؛ از ساخت Application در DB API Marketplace تا دریافت داده، Parse کردن XML، شناسایی فیلدهای مهم و Match کردن داده Planned و Changed برای محاسبه Delay.

هدف این بخش، اضافه کردن یک منبع عملیاتی واقعی به Data Warehouse فعلی بود تا در آینده بتوان شاخص‌هایی مانند موارد زیر را محاسبه کرد:

- تأخیر ورود
- تأخیر خروج
- تغییر سکو
- لغو قطار
- Punctuality
- Scheduled vs. Changed Performance

---

# 1. مسئله اصلی

فاز اول پروژه بر اساس داده‌های GTFS برنامه‌ریزی‌شده NRW ساخته شد.

Scope فعلی پروژه روی این سرویس‌ها متمرکز است:

```text
RE
RB
S-Bahn
```

Data Warehouse فعلی اطلاعاتی مانند موارد زیر دارد:

```text
Service Date
Route
Station
Stop Sequence
Scheduled Arrival
Scheduled Departure
```

اما Scheduled Data به‌تنهایی نمی‌تواند پاسخ دهد:

```text
آیا قطار تأخیر داشت؟
چند دقیقه تأخیر داشت؟
آیا سکو تغییر کرد؟
آیا سرویس لغو شد؟
کدام Route عملکرد ضعیف‌تری دارد؟
کدام Station بیشتر تحت تأثیر تأخیر قرار می‌گیرد؟
```

بنابراین به یک منبع عملیاتی واقعی نیاز داشتیم.

برای Proof of Concept، API رسمی Deutsche Bahn انتخاب شد:

```text
DB Timetables API
```

---

# 2. چرا DB Timetables API؟

دو Endpoint اصلی برای این پروژه اهمیت دارند.

Planned timetable:

```text
/plan
```

Changed timetable:

```text
/fchg
```

در نتیجه می‌توانیم:

```text
Planned Data
    +
Changed Data
    ↓
Match
    ↓
Delay Calculation
```

داشته باشیم.

مثال:

```text
Planned Arrival = 11:15
Changed Arrival = 11:23
Delay           = 8 minutes
```

این دقیقاً پایه مورد نیاز برای Railway Performance Analytics است.

---

# 3. ساخت Application در DB API Marketplace

ابتدا در DB API Marketplace ثبت‌نام شد.

سپس یک Application با نامی مشابه زیر ساخته شد:

```text
NRW Rail Performance Analytics
```

Application به محصول زیر Subscribe شد:

```text
Timetables API
```

برای Authentication دو Credential دریافت شد:

```text
DB-Client-ID
DB-Api-Key
```

## نکته امنیتی

این مقادیر نباید:

- در Git Commit شوند
- داخل README قرار بگیرند
- در Screenshot دیده شوند
- در SQL Script ذخیره شوند
- داخل Source Code عمومی Hard-code شوند

برای Proof of Concept فقط در Variableهای PowerShell نگهداری شدند:

```powershell
$clientId = "YOUR_CLIENT_ID"
$apiKey   = "YOUR_API_KEY"
```

سپس Header درخواست ساخته شد:

```powershell
$headers = @{
    "DB-Client-ID" = $clientId
    "DB-Api-Key"   = $apiKey
}
```

---

# 4. چرا PowerShell؟

در این مرحله هدف ساخت Pipeline نهایی نبود.

ابتدا لازم بود Source واقعی را بررسی کنیم.

PowerShell برای این کار مناسب بود چون امکان می‌داد:

- HTTP Request ارسال کنیم
- Authentication انجام دهیم
- Raw Response را ببینیم
- XML را Parse کنیم
- ساختار داده را بررسی کنیم
- Identifierها را پیدا کنیم
- Plan و Change را Match کنیم
- Delay را محاسبه کنیم

اصل مهم این مرحله:

> ابتدا Source واقعی را بررسی کن، سپس Schema دیتابیس را طراحی کن.

این کار ریسک طراحی جدول‌های اشتباه بر اساس حدس را کاهش می‌دهد.

---

# 5. پیدا کردن EVA Number ایستگاه Köln Hbf

DB برای Stationها از شناسه‌ای به نام:

```text
EVA Number
```

استفاده می‌کند.

ایستگاه انتخاب‌شده برای Proof of Concept:

```text
Köln Hbf
```

ابتدا با Endpoint مربوط به Station، EVA را پیدا کردیم.

```powershell
$response = Invoke-WebRequest `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/station/K%C3%B6ln%20Hbf" `
  -Headers $headers
```

بعد Response:

```powershell
$response.Content
```

خروجی XML شامل این مقدار بود:

```xml
<station
    name="Köln Hbf"
    eva="8000207"
/>
```

بنابراین:

```text
Station = Köln Hbf
EVA     = 8000207
```

---

# 6. استفاده از UseBasicParsing

در اولین Request، Windows PowerShell یک Security Warning مربوط به Parsing نمایش داد.

برای Requestهای بعدی از این گزینه استفاده شد:

```powershell
-UseBasicParsing
```

مثال:

```powershell
Invoke-WebRequest `
    -UseBasicParsing `
    ...
```

---

# 7. دریافت Planned Timetable

EVA در Variable قرار گرفت:

```powershell
$eva = "8000207"
```

برای Endpoint مربوط به Plan، تاریخ و ساعت لازم است.

```powershell
$date = "260822"
$hour = "11"
```

فرمت تاریخ:

```text
yyMMdd
```

بنابراین:

```text
260822
```

یعنی:

```text
22.08.2026
```

Request:

```powershell
$planResponse = Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/plan/$eva/$date/$hour" `
  -Headers $headers
```

نمایش Raw Response:

```powershell
$planResponse.Content
```

Response شامل تعداد زیادی Train Movement بود، از جمله:

```text
S-Bahn
RE
RB
ICE
FLX
```

---

# 8. Parse کردن XML

برای کار راحت‌تر، Response به XML Object تبدیل شد:

```powershell
[xml]$planXml = $planResponse.Content
```

برای مشاهده فقط سه رکورد:

```powershell
$planXml.timetable.s |
    Select-Object -First 3 |
    Format-List *
```

ساختار ساده‌شده یک Record:

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

# 9. فیلدهای مهم Planned Data

## s.id

شناسه Event یا Timetable Stop است.

مثال:

```text
2958834342628665585-2608220720-5
```

این ID برای Match کردن Planned و Changed Data اهمیت زیادی دارد.

---

## tl

اطلاعات Train را نگه می‌دارد.

```xml
<tl c="S" n="32170" />
```

معنی:

```text
c = Train Category
n = Train Number
```

---

## ar

اطلاعات Arrival:

```xml
<ar
    pt="2608221115"
    pp="4"
    fb="EUR 9411"
/>
```

فیلدهای مهم:

```text
pt = Planned Time
pp = Planned Platform
```

---

## dp

اطلاعات Departure:

```text
pt = Planned Departure Time
pp = Planned Departure Platform
```

---

## l

Line را مشخص می‌کند.

مثلاً:

```text
S11
RE7
RB25
```

---

## ppth

مسیر برنامه‌ریزی‌شده قطار را به‌صورت Station Path نشان می‌دهد.

---

# 10. دریافت Changed Data

برای دریافت تغییرات عملیاتی از:

```text
/fchg/{EVA}
```

استفاده شد.

برای Köln Hbf:

```text
/fchg/8000207
```

PowerShell:

```powershell
$changeResponse = Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/fchg/$eva" `
  -Headers $headers
```

سپس:

```powershell
[xml]$changeXml = $changeResponse.Content
```

و:

```powershell
$changeXml.timetable.s |
    Select-Object -First 3 |
    Format-List *
```

---

# 11. Changed Time

در یکی از Recordها این مقدار مشاهده شد:

```xml
<ar ct="2608221123" />
```

اینجا:

```text
ct = Changed Time
```

مقدار:

```text
2608221123
```

یعنی:

```text
22.08.2026 11:23
```

پس:

```text
pt = Planned Time
ct = Changed Time
```

---

# 12. پیدا کردن اولین Record دارای Changed Arrival

```powershell
$changed = $changeXml.timetable.s |
    Where-Object { $_.ar.ct } |
    Select-Object -First 1
```

نمایش ID:

```powershell
$changed.id
```

نمایش Arrival XML:

```powershell
$changed.ar.OuterXml
```

خروجی:

```xml
<ar ct="2608221123" />
```

ID:

```text
2958834342628665585-2608220720-5
```

---

# 13. Match کردن Planned و Changed

ID مربوط به Changed Record ذخیره شد:

```powershell
$id = $changed.id
```

سپس همان ID در Plan جست‌وجو شد:

```powershell
$planned = $planXml.timetable.s |
    Where-Object { $_.id -eq $id } |
    Select-Object -First 1
```

برای Validation:

```powershell
$planned.id
```

Planned Arrival:

```powershell
$planned.ar.OuterXml
```

Changed Arrival:

```powershell
$changed.ar.OuterXml
```

نتیجه Planned:

```xml
<ar
    pt="2608221115"
    pp="4"
    fb="EUR 9411"
/>
```

نتیجه Changed:

```xml
<ar ct="2608221123" />
```

بنابراین:

```text
Planned Arrival = 11:15
Changed Arrival = 11:23
```

Delay:

```text
8 minutes
```

این اولین Validation واقعی Planned vs. Changed در پروژه بود.

---

# 14. منطق Match

```text
/plan
   │
   │ id
   ▼
Match
   ▲
   │ id
   │
/fchg
```

از نظر منطقی:

```text
plannedStop.id = changedStop.id
```

و:

```text
Arrival Delay =
Changed Arrival
-
Planned Arrival
```

برای Departure نیز همین منطق قابل استفاده است.

---

# 15. تبدیل Timestamp به DateTime

Timestampهای DB به فرم Compact هستند.

مثلاً:

```text
2608221115
```

فرمت:

```text
yyMMddHHmm
```

در PowerShell:

```powershell
$plannedArrival = [datetime]::ParseExact(
    $plannedStop.ar.pt,
    "yyMMddHHmm",
    $null
)
```

Changed:

```powershell
$changedArrival = [datetime]::ParseExact(
    $changedStop.ar.ct,
    "yyMMddHHmm",
    $null
)
```

محاسبه Delay:

```powershell
($changedArrival - $plannedArrival).TotalMinutes
```

---

# 16. اسکریپت چند Record

برای Generalize کردن همین منطق:

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

نمایش:

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

---

# 17. Mapping فیلدهای API

| API Field | معنی |
|---|---|
| `s.id` | شناسه Timetable Event |
| `s.eva` | Station EVA |
| `tl.c` | Train Category |
| `tl.n` | Train Number |
| `ar.pt` | Planned Arrival |
| `ar.ct` | Changed Arrival |
| `ar.pp` | Planned Arrival Platform |
| `ar.cp` | Changed Arrival Platform |
| `ar.l` | Line |
| `ar.fb` | Train / Service Designation |
| `dp.pt` | Planned Departure |
| `dp.ct` | Changed Departure |
| `dp.pp` | Planned Departure Platform |
| `dp.cp` | Changed Departure Platform |
| `ppth` | Planned Station Path |

همه Fieldها در همه Recordها وجود ندارند.

در طراحی Parser نهایی باید Optional بودن فیلدها در نظر گرفته شود.

---

# 18. ارتباط با Data Warehouse

معماری فعلی:

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

منبع جدید:

```text
DB Timetables API
       ↓
/station
/plan
/fchg
       ↓
PowerShell Proof of Concept
       ↓
Future Operational Staging
       ↓
Delay / Cancellation Processing
       ↓
Performance Analytics
```

تصویر کلی:

```text
GTFS Scheduled Data
        +
DB Operational Data
        ↓
Scheduled vs. Changed
        ↓
NRW Rail Performance Analytics
```

---

# 19. دلیل اهمیت این بخش در پروژه

این بخش Skillهای مختلفی را همزمان نشان می‌دهد:

- External API Integration
- API Authentication
- PowerShell
- HTTP Requests
- XML Parsing
- Data Discovery
- Identifier Matching
- DateTime Transformation
- Business KPI Calculation
- Data Warehouse Design Thinking

PowerShell در این پروژه فقط یک ابزار Command Line نبود.

از آن به‌عنوان یک **Data Exploration و API Prototyping Layer** استفاده شد.

---

# 20. توضیح پیشنهادی در مصاحبه

می‌توان این قسمت را این‌طور توضیح داد:

> در ابتدا Data Warehouse را با داده‌های GTFS برنامه‌ریزی‌شده NRW ساختم. اما Scheduled Data برای Performance Analytics کافی نبود، چون Delay و Cancellation را نشان نمی‌داد. بنابراین DB Timetables API را بررسی کردم. قبل از طراحی جدول‌های Actual، با PowerShell یک Proof of Concept ساختم. ابتدا Köln Hbf را به EVA Number تبدیل کردم، سپس با `/plan` داده Planned و با `/fchg` داده Changed را گرفتم. XML Responseها را Parse کردم و با استفاده از ID مشترک، یک Event واقعی را Match کردم. Planned Arrival آن 11:15 و Changed Arrival آن 11:23 بود و Delay هشت دقیقه محاسبه شد. این مرحله به من اجازه داد قبل از طراحی SQL Schema، ساختار واقعی Source را Validate کنم.

نسخه کوتاه:

> I used PowerShell as an API exploration and prototyping layer before extending the SQL Server warehouse. I validated authentication, XML parsing, identifier matching and planned-versus-changed delay calculation on real Deutsche Bahn operational data.

---

# 21. اصل مهندسی این مرحله

مهم‌ترین اصل این مرحله:

> **External Source را بر اساس فرض طراحی نکن؛ ابتدا داده واقعی را دریافت، Parse و Validate کن.**

مسیر Proof of Concept:

```text
DB API Application
        ↓
Authentication
        ↓
Station Lookup
        ↓
EVA Number
        ↓
/plan
        ↓
Planned XML
        ↓
/fchg
        ↓
Changed XML
        ↓
ID Matching
        ↓
Delay Calculation
```

این Proof of Concept پایه مرحله بعدی پروژه است: طراحی یک **Operational / Actual Data Ingestion Layer** برای SQL Server و تبدیل پروژه از Schedule Analytics به Performance Analytics.
