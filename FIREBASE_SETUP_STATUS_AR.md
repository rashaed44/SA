# حالة ربط Firebase — SALO

## ما نُفّذ في مصدر التطبيق

- أُضيف `google-services.json` المطابق للمشروع `salo-production-13fae` ومعرّف Android `com.dardshti.app`، مع Firebase Core وGoogle Services Gradle plugin.
- أُضيفت حزم `firebase_auth` و`cloud_firestore` و`cloud_functions`.
- انتقلت شاشة المصادقة إلى Email/Password؛ يوجد تحقق بريد وإعادة تعيين كلمة المرور ورسائل خطأ عربية، مع تحديد محاولات مصادقة عبر Cloud Function.
- البريد لا يدخل وثيقة `users` العامة؛ يحفظ سجل البريد في `privateUsers/{uid}`، وتمنع القواعد قراءة السجل الخاص عن الآخرين.
- رسائل المستخدمين الجدد، وقوائم المحادثات، والستوريات، والمجموعات، والإعدادات أصبحت تستخدم Firebase بدل REST.
- أضيفت وظيفة إنشاء محادثة مباشرة ببحث username، وحدود معدل لكل عمليات الكتابة، وحد payload مقداره 2MB.
- استعلامات Stories مقيدة العدد والمدة؛ فحص الصداقة المقبولة المتبادلة والحظر يُنفذ بقراءة مجمعة بدل lookup لكل قصة/مستخدم.
- قواعد Firestore مغلقة افتراضيًا وتمنع العميل من كتابة الرسائل والقصص والمجموعات والملفات الداخلية؛ قواعد Storage تقصر الرفع على صور JPEG/PNG/WebP للملف الشخصي بحد 5MB.
- أضيفت رؤوس حماية إلى Firebase Hosting، وحُدّدت CORS للنطاقات المعروفة للمشروع.
- Firestore: `eur3` حسب اختيار المستخدم. Functions: `europe-west1`.

## ما لم يحدث خارج بيئة المصدر

لم يتم تسجيل الدخول إلى Firebase CLI، ولم تُنشأ قاعدة Firestore أو تُفعّل Email/Password، ولم تُنشر القواعد أو الوظائف. يتطلب النشر تفعيل خطة Blaze مع فوترة؛ راجع حدود الإنفاق والتنبيهات قبل التفعيل. ملف Service Account المرفق سابقًا لم يُستخدم، ويجب إلغاء مفتاحه من Google Cloud IAM. لا ترفع مفاتيح خدمة إلى المشروع.

App Check غير مفروض بعد لتجنب منع التطبيق قبل تسجيل اعتماد Play Integrity ومفتاح Web. iOS يحتاج تسجيل التطبيق وإضافة `GoogleService-Info.plist`. بُني APK Debug بنجاح في `../SALO_1.4.0_debug.apk` بمعرّف `com.dardshti.app` وإصدار `1.4.0` ورقم `versionCode=5`؛ هو للتجربة على Android وليس إصدار متجر.

لا يوجد Backend أو تصدير بيانات قديمة موثوق ضمن الملفات المستلمة؛ لذلك لم تُنقل حسابات أو محادثات/Stories تاريخية. لن تعمل بيانات REST القديمة تلقائيًا بعد التحويل. يلزم ملف تصدير من مصدر موثوق وخطة mapping/تحقق قبل استيراد بيانات قديمة.

## تحقق محلي

نجح `flutter pub get`، و`flutter analyze --no-fatal-infos` دون أخطاء أو تحذيرات (بقيت 21 ملاحظة معلوماتية عن أسلوب/deprecations)، ونجح `flutter test` (الاختبار الموجود). نجح `npm run check` و`npm run build` لوظائف TypeScript، و`npm audit --omit=dev --audit-level=high` لم يجد ثغرات عالية أو حرجة في اعتماديات الإنتاج. الدليل `FIREBASE_DEPLOYMENT_AR.md` يشرح الإعداد والنشر من حساب المالك.
