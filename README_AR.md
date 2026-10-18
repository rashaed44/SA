# SALO Flutter — الإصدار 1.4.0

تطبيق Flutter مهيّأ للاتصال بمشروع Firebase `salo-production-13fae`.

## المنفذ في المصدر

- Android `applicationId` و`namespace`: `com.dardshti.app`، متوافقان مع تسجيل Android في Firebase. الإصدار `1.4.0` ورقم البناء `5`.
- Firebase Core وEmail/Password Auth وFirestore وCloud Functions مُهيأة على Android وWeb.
- تسجيل بريد إلكتروني جديد يتضمن التحقق من البريد، واستعادة كلمة المرور، وملف مستخدم عام بلا بريد إلكتروني.
- نقل المصادقة والجلسات من REST إلى Firebase؛ لا يوجد Backend REST قديم ضمن المرفقات.
- محادثات مباشرة بالـusername، ورسائل حيّة عبر Firestore، وStories ومجموعات وإعدادات باستخدام Functions موثوقة وقواعد مقفلة.
- `eur3` هو موقع Firestore المختار، وFunctions في `europe-west1`.
- CORS محدود إلى نطاقي Firebase Hosting للمشروع؛ Security Headers مضافة إلى Firebase Hosting.
- حد payload قدره 2MB، وتحديد محاولات المصادقة حسب IP/البريد، والرسائل والستوريات والمجموعات والإعدادات.
- Stories ترفض أنواع الوسائط غير المدعومة (النص فقط)، وفحص الأصدقاء المتبادل والحظر يتم مجمّعًا؛ لا يوجد استعلام مستخدم لكل Story.

## قبل الاستخدام الفعلي

1. فعّل Email/Password في Firebase Authentication.
2. أنشئ Firestore يدويًا بموقع `eur3` قبل النشر؛ الموقع لا يمكن تغييره بعد الإنشاء.
3. سجّل الدخول إلى Firebase CLI من جهاز المالك، ثم انشر قواعد Firestore وStorage وIndexes وFunctions كما في [دليل النشر](FIREBASE_DEPLOYMENT_AR.md). يتطلب نشر Cloud Functions خطة Blaze.
4. أضف App Check (Play Integrity على Android ومفتاح الموقع على Web) واختبره قبل فرضه.
5. أضف نطاق Web الفعلي إلى Auth authorized domains و`functions/src/index.ts`؛ لا تستخدم wildcard.
6. لا توجد قاعدة تصدير قديمة أو Backend موثوق في المواد المستلمة، لذا لا يمكن استيراد حسابات/رسائل قديمة. الحسابات الجديدة تعمل ببريد إلكتروني وكلمة مرور؛ صاحب الحساب القديم الذي لديه بريد موثق يمكنه محاولة استعادة كلمة المرور إذا كان ذلك البريد موجودًا أصلًا في Firebase Auth.
7. تهيئة iOS لا تزال تنتظر تسجيل تطبيق iOS وملف `GoogleService-Info.plist`.

## الفحص المحلي

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
cd functions && npm install && npm run check
```

بُني APK Debug للتثبيت التجريبي على Android. ملفه `SALO_1.4.0_debug.apk` منفصل عن حزمة المصدر. لا تستخدمه للنشر في المتجر؛ لم يُجهز مفتاح توقيع إصدار، كما أن وظائف Firebase وقاعدة Firestore لم تُنشأ أو تُنشر بعد.
