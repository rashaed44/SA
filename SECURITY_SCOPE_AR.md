# نطاق الأمان — SALO Firebase

## الإصلاحات المنفذة في المصدر

- **CORS:** Callable Functions تقبل نطاقي Firebase Hosting التابعين للمشروع فقط، ولا تسمح بأصل wildcard.
- **CSRF والجلسات:** التطبيق لم يعد يستخدم جلسات Cookie؛ يستخدم Firebase Auth ID tokens وCallable Functions. لذلك لا توجد جلسة Cookie تقبل CSRF هنا. يجب إعادة تقييم هذه النقطة إذا أضيفت لاحقًا جلسات Cookie أو Backend ويب آخر.
- **Rate limiting:** محاولات الدخول والتسجيل وإعادة التعيين محدودة بحسب IP وبريد مجزأ، مع حدود إضافية لإنشاء الملف والمحادثة والرسالة وقراءة/إنشاء/حذف Stories وإنشاء/الانضمام للمجموعات وحفظ الإعدادات. Firebase Auth يطبق أيضًا حماية الإساءة الخاصة به.
- **حجم الطلب:** كل Callable Function تقيس الطلب وتمنع الطلبات الأكبر من 2MB، مع حدود أقصر للنصوص بحسب النوع.
- **Stories:** استعلامات محدودة (حتى 50 صديقًا مقبولًا في نافذة التحميل، و100 قصة نهائية)، مع فحص صداقة متبادل وحظر عبر قراءات مجمعة، ومن دون قراءة ملف مستخدم لكل قصة. أنواع Stories المسموحة هي النص فقط.
- **خصوصية الملف الشخصي:** لا يُخزّن البريد في وثيقة الملف العامة `users`؛ يبقى في `privateUsers` التي لا يقرأها إلا صاحب الحساب.
- **أنواع الملفات:** Storage يسمح بصور JPEG/PNG/WebP فقط وبحد 5MB لمسار الصورة الشخصية، ويمنع بقية المسارات. لا توجد ميزة رفع Story/رسالة مفعلة بعد. تحقق MIME في قواعد Storage يعتمد على metadata المقدمة، ولذلك يلزم فحص محتوى الملف خادميًا قبل فتح أنواع رفع إضافية.
- **Security Headers:** أضيفت `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, و`Strict-Transport-Security` إلى Firebase Hosting.
- **Android:** `applicationId` و`namespace` متطابقان مع `com.dardshti.app`، الإصدار `1.4.0` ورقم `versionCode` هو 5.
- **الخصوصية والقواعد:** Firestore مغلق افتراضيًا؛ عمليات إنشاء/تعديل الرسائل والستوريات والمجموعات والملفات الداخلية تمر عبر وظائف الخادم.

## نقاط تتطلب إعداد/نشر

1. لم تُنشر القواعد أو Cloud Functions بعد، ولم تُنشأ قاعدة Firestore. إعداد `eur3` وEmail/Password يجب أن يتم من حساب مالك Firebase، ثم نشر الملفات عبر CLI. النشر يتطلب Blaze.
2. **App Check غير مفروض**؛ يجب إعداد Play Integrity وWeb reCAPTCHA/App Check ثم فرضه بعد اختبار اعتماد التطبيق.
3. عدادات Rate Limit محفوظة في Firestore وبمعاملات، لكنها ليست Cloud Armor/WAF؛ استخدم Firebase App Check وحماية DDoS/edge مناسبة عند التوسع. حاليًا يوجد حد maxInstances.
4. حد 2MB داخل الوظيفة يُراجع بعد وصول الطلب إلى callable runtime؛ ليس بديلًا عن حدود شبكة/Proxy. كل مدخلات التطبيق النصية محدودة كذلك.
5. لا يوجد Backend REST قديم أو export موثوق في المواد، لذلك لم تُرحّل بيانات تاريخية. تُستخدم حسابات Firebase الجديدة بالبريد وكلمة المرور؛ لا يمكن إعادة تعيين حساب غير مستورد إلى Firebase Auth.
6. iOS غير مهيأ حتى تسجيل تطبيقه وإضافة `GoogleService-Info.plist`.
7. بُني APK Debug واختُبر توقيعه؛ لا يوجد مفتاح Release للنشر في المتجر. لم يتم نشر Firebase أو إجراء تغييرات على المشروع الفعلي.

## الملفات ذات الصلة

- `functions/src/index.ts`
- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules`
- `firebase.json`
- `FIREBASE_DEPLOYMENT_AR.md`
