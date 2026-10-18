# إعداد Firebase ونشر SALO

## إعداد المشروع من Firebase Console

1. في مشروع `salo-production-13fae` فعّل **Authentication → Sign-in method → Email/Password**.
2. أنشئ Cloud Firestore في وضع Production واختر `eur3` قبل الإنشاء؛ الموقع لا يمكن تغييره لاحقًا.
3. راجع ملف `google-services.json` في `android/app/` وتأكد من تطابق `package_name` مع `com.dardshti.app`.
4. إذا استُخدم إصدار الويب، أضف نطاق الاستضافة الفعلي في Auth Authorized domains ولقائمة CORS داخل `functions/src/index.ts`. لا تضف `*`.
5. لا ترفع أو ترسل ملف Service Account JSON. المفتاح الذي رُفع في هذه الجلسة حُذفت نسخته المحلية ولم يُستخدم؛ يجب إلغاؤه من Google Cloud IAM → Service Accounts → Keys.

## النشر من جهاز موثوق

يتطلب نشر Cloud Functions تفعيل خطة Firebase Blaze وربط حساب فوترة. هذا لا يعني أن الاستخدام سيكلف مبلغًا ثابتًا؛ الرسوم تعتمد على الاستهلاك، لذلك راجع حدود المشروع والتنبيهات قبل التفعيل. يمكن اختبار الوظائف محليًا عبر Emulator دون نشر.

من جذر المشروع، بعد تسجيل الدخول إلى Firebase CLI بحساب المالك على جهاز موثوق وبعد إنشاء Firestore:

```bash
firebase login
firebase use salo-production-13fae
cd functions && npm install && npm run build && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

لا يحتاج المشروع إلى مفتاح Service Account داخل المستودع. استخدم تسجيل Firebase CLI الشخصي للنشر اليدوي أو هوية Workload Identity / Secret Manager في CI.

## ما لم يُنشر من هذه البيئة

ملفات القواعد والوظائف وتهيئة العميل تُجهّز محليًا فقط. لم يتم إنشاء قاعدة Firestore أو تغيير إعدادات المشروع أو نشر Cloud Functions؛ ذلك يتطلب تسجيل دخول المالك وتفعيل الفوترة على المشروع. يجب إعداد App Check على Android (Play Integrity) ومراقبة المقاييس قبل تفعيل `enforceAppCheck`، كي لا تُرفض نسخ التطبيق قبل تهيئة الاعتماد.
