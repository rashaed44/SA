# قرارات ربط Firebase في SALO

## الخيارات المعتمدة

- معرّف المشروع: `salo-production-13fae`.
- منطقة Firestore التي اختارها المستخدم: `eur3` (أوروبا متعددة المناطق). يلزم إنشاء قاعدة البيانات يدويًا من Firebase Console بهذه المنطقة؛ لا يمكن تغييرها بعد الإنشاء.
- منطقة Cloud Functions: `europe-west1`، وهي أقرب منطقة Functions موصى بها لـ`eur3` وفق جدول Firebase الرسمي.
- مصادقة الحسابات الجديدة: Firebase Authentication بالبريد الإلكتروني وكلمة المرور، مع طلب التحقق من البريد قبل استخدام البيانات.
- لن تُخزّن عناوين البريد في وثائق الملف العام؛ البريد محصور في `privateUsers/{uid}` ومتاح لصاحب الحساب فقط.
- لا توجد خدمة Backend قديمة في الحزمة، لذلك لن يُستخدم جسر username/password قديم. استيراد الحسابات والبيانات القديمة ينتظر ملف تصدير موثوقًا ومنقحًا.
- واجهات Cloud Functions تستخدم CORS لقائمة نطاقات Firebase Hosting الخاصة بالمشروع فقط. تطبيق Android لا يعتمد على Cookies؛ لذلك لا توجد جلسة Cookie تحتاج CSRF، وتُستخدم رموز Firebase Auth مع تحقق الخادم من المستخدم والبريد.
- كتابات الرسائل والستوريات والمجموعات والإعدادات تمر عبر callable functions ذات حدود طلبات، وتُمنع الكتابة المباشرة من العميل بقواعد Firestore.
- أنواع القصص المقبولة حاليًا نص فقط. تخزين الوسائط غير مفتوح حتى إعداد مسارات تحققها؛ صور الملفات الشخصية تقبل JPEG/PNG/WebP وبحد أقصى 5MB.

## المصادر الرسمية

1. Firebase Functions locations — يوصي بـ`europe-west1` لـFirestore multi-region `eur3`: https://firebase.google.com/docs/functions/locations
2. Callable Cloud Functions — يشرح تقييد CORS والتحقق من `request.auth`: https://firebase.google.com/docs/functions/callable
3. App Check enforcement for Cloud Functions — يلزم إعداد App Check في المشروع والعميل قبل فرضه: https://firebase.google.com/docs/app-check/cloud-functions
4. Firebase Cloud Functions get started — النشر يتطلب خطة Blaze، بينما يمكن تشغيل Emulator دون النشر: https://firebase.google.com/docs/functions/get-started
5. Firestore locations — اختيار الموقع ثابت بعد إنشاء قاعدة البيانات: https://firebase.google.com/docs/firestore/locations
6. Firebase Flutter release notes — مرجع توافق إصدارات FlutterFire: https://firebase.google.com/support/release-notes/flutter
