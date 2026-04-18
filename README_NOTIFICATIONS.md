# إصلاح إشعارات Firebase Cloud Messaging (FCM)

## المشكلة
كانت الإشعارات لا تعمل بسبب استخدام FCM Legacy API الذي تم إغلاقه رسميًا في يونيو 2024.

## الحل
تم تحديث الكود لاستخدام FCM HTTP v1 API الجديد مع Service Account و Access Token.

## الخطوات المطلوبة

### 1. تحميل ملف Service Account JSON
1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك (enjaz7-a49f2)
3. اضغط على الإعدادات (Settings) → Service Accounts
4. اضغط "Generate new private key"
5. احفظ الملف باسم `firebase-service-account.json` في مجلد المشروع الرئيسي

### 2. تثبيت التبعيات
```bash
npm install
```

### 3. اختبار الإشعارات
```bash
node scripts/send_notification.js
```

## ملاحظات مهمة
- تأكد من وجود ملف `firebase-service-account.json` في المجلد الرئيسي
- الكود يستخدم Access Token ديناميكي بدلاً من Server Key الثابت
- جميع الإشعارات تحتوي على `notification{}` لتظهر على الأجهزة
- تم استخدام topics لإرسال الإشعارات للمجموعات

## الدوال المتاحة
- `sendGeneralUpdate()` - إشعار تحديث عام
- `sendBusArrival(lineNumber, stopName)` - إشعار وصول حافلة
- `sendTrafficAlert(description)` - إشعار زحمة مرورية
- `sendOfferNotification(offerText)` - إشعار عرض خاص
- `sendPalestineNotification()` - إشعار فلسطين

## استيراد في السيرفر
```javascript
const { sendGeneralUpdate, sendBusArrival } = require('./scripts/send_notification.js');
```

الآن الإشعارات ستعمل بشكل صحيح مع FCM HTTP v1 API الجديد! 🎉
