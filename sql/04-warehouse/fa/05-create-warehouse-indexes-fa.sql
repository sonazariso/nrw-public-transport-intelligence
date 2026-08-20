USE NRWTransportDW;
GO

/*
هدف
---
ایجاد Indexهای تحلیلی روی Fact Table نهایی فاز اول.

چرا این Indexها لازم هستند؟
---------------------------
جدول dw.FactTripStop بیش از 8 میلیون ردیف دارد.

Primary Key خوشه‌ای جدول روی FactTripStopKey است.
این کلید برای شناسایی یکتای هر ردیف مناسب است، اما بیشتر Queryهای تحلیلی
بر اساس FactTripStopKey اجرا نمی‌شوند.

دو Nonclustered Index واقعی که در پروژه ساخته شدند، دو الگوی اصلی Query را پوشش می‌دهند:

1. تحلیل بر اساس Date / Route / Stop
2. دنبال کردن یک TripInstance بر اساس ترتیب StopSequence

این Indexها بعد از Load کامل Fact Table ساخته شدند.

چرا بعد از Load؟
---------------
اگر Indexها قبل از Insert میلیون‌ها ردیف ساخته می‌شدند،
SQL Server هنگام Insert هر ردیف مجبور بود ساختار Indexها را نیز به‌روزرسانی کند.

به همین دلیل ابتدا:

- Fact Table Load شد
- تعداد ردیف‌ها Validation شد
- Grain بررسی شد

و سپس Indexهای Reporting اضافه شدند.
*/


/*
Index شماره 1
-------------
برای Queryهایی که بر اساس موارد زیر Filter یا Group می‌شوند:

- Date
- Route
- Stop

این Index برای گزارش‌های Data Warehouse و Power BI آینده مفید است،
برای مثال:

- حجم سرویس برنامه‌ریزی‌شده بر اساس تاریخ
- تحلیل Route
- تحلیل Stop / Station
*/

CREATE INDEX IX_FactTripStop_DateRouteStop
ON dw.FactTripStop
(
    DateKey,
    RouteKey,
    StopKey
);
GO


/*
Index شماره 2
-------------
برای بازیابی Stopهای مربوط به یک TripInstance
به ترتیب StopSequence استفاده می‌شود.

الگوی معمول Query:

WHERE TripInstanceKey = ...
ORDER BY StopSequence
*/

CREATE INDEX IX_FactTripStop_TripInstance
ON dw.FactTripStop
(
    TripInstanceKey,
    StopSequence
);
GO


/*
وضعیت Implementation
--------------------
هر دو Index بالا در SQL Server واقعاً ساخته و اجرا شده‌اند.

هیچ Index دیگری در این فایل به‌عنوان Implemented ثبت نشده است،
مگر اینکه واقعاً ساخته و بررسی شده باشد.

Foreign Keyهای فیزیکی Fact Table نیز در این مرحله داخل فایل قرار نگرفته‌اند،
چون تا این نقطه هنوز واقعاً اجرا نشده بودند.
*/
