# تقرير جرد SALO وFirebase

## الخلاصة

المشروع المرفق تطبيق **Flutter/Dart** صغير يتصل بـBackend عبر REST؛ وليس مستودع SALO الكامل أو خادم الإنتاج. بعد استلام إعداد Firebase Android، أضيفت تهيئة Firebase Core إلى Android وWeb فقط. لم يتغير مسار المصادقة أو البيانات؛ فما زال مصدر الحقيقة الحالي REST إلى أن يجهز جسر آمن.

## الموجود في ملفات المشروع

- نقطة الدخول: `lib/main.dart`، والتطبيق/الثيم/التنقل: `lib/app.dart`, `lib/core/theme/salo_theme.dart`, و`lib/features/home/salo_shell.dart`.
- المصادقة: `lib/features/auth/auth_gate.dart` و`lib/data/repositories/auth_repository.dart` تستخدم `SaloApiClient` مع مسارات REST:
  - `POST /api/legacy/auth/login`
  - `POST /api/legacy/auth/register`
  - `GET /api/legacy/auth/me`
  - `POST /api/legacy/auth/logout`
- واجهة الدخول تأخذ **اسم مستخدم وكلمة مرور**. يحصل العميل على Token من الخادم ويحفظه في `flutter_secure_storage` بالمفتاح `dardshti_api_token`، ويرسله كـBearer token.
- نموذج `lib/data/models/salo_user.dart` يحتوي `id` من نوع `int?`, `username`, `displayName`, و`email?`. لا يوجد UID Firebase ولا ربط معروف بين معرّف الخادم وUID.
- الرسائل والمحادثات والمجموعات والقصص وإعدادات الحساب تستعمل REST API عبر `lib/core/networking/salo_api_client.dart`؛ القصص والمحتوى يستعملان `/api/legacy/content/...`، وتخزين الإعدادات يزامن `/api/legacy/state` مع `SharedPreferences` محليًا.
- الواجهات الموجودة محدودة: المحادثات، القصص النصية، الإعدادات، والمجموعات. لم يظهر في الملفات الحالية تدفق مرفقات/رفع ملفات/FCM/لوحة إدارة.
- Android `applicationId` و`namespace` و`MainActivity` تشير إلى `com.dardshti.app`. إعداد iOS موجود لكن لا يوجد إعداد Capacitor.

## غير الموجود في المشروع

لم تظهر في ملفات الحزمة:

- أضيفت تبعية `firebase_core` وملف `lib/firebase_options.dart`، وأضيف `android/app/google-services.json`، وسجلت إضافة Google Services Gradle plugin.
- لم تُضف بعد `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging` أو App Check. لا يوجد `GoogleService-Info.plist` لـiOS ولا `capacitor.config.*`.
- مجلد `functions/` أو قواعد `firestore.rules`/`storage.rules` أو `firestore.indexes.json`.
- مخطط/اتصال قاعدة البيانات أو Backend source أو لوحة الإدارة أو بيانات Collections الفعلية.
- إعداد موصل Firebase في إعدادات الجلسة. لم أطلب بيانات سرية ولم أجر اتصالًا بمشروع Firebase.

وبالتالي لا توجد Collections أو قواعد Firebase حالية يمكن الحفاظ عليها أو مقارنة الاقتراح بها. أسماء Collections الواردة في طلبك تعد **مخططًا مقترحًا** وليست وصفًا مثبتًا لبيانات موجودة. كما لا يمكن معرفة الأدوار الحالية أو إنشاء أول owner بأمان من العميل وحده.

## مخاطر وقرارات قبل التنفيذ

1. اختير جسر مؤقت: username/password يتحقق منه Backend موثوق ثم يصدر Firebase Custom Token. ما زال يلزم رابط API الإنتاجي أو مصدر Backend؛ لا يصلح عنوان المحاكي المحلي من Cloud Function.
2. استبدال مسارات REST بكتابات Firestore مباشرة سيحوّل مصدر الحقيقة ويؤثر على الدردشة والقصص والمجموعات والبيانات القديمة. المسار الآمن الافتراضي هو تشغيل متوافق مرحليًا، لكنه يحتاج تحديد ما يبقى على Backend الحالي وما ينتقل إلى Firebase.
3. قواعد Firebase وCloud Functions لا تُنشر ولا تُختبر على مشروع حقيقي دون تحديد مشروع Firebase وامتلاك وصول مناسب إليه. لا ينبغي وضع service-account أو أسرار في التطبيق أو رفعها إلى الأرشيف.
4. ثُبّت Flutter 3.47.7 وشُغّلت اختبارات Flutter. لا يتوفر Android SDK أو اتصال Firebase CLI، لذلك لم يُبنَ APK ولم تُنشر قواعد أو وظائف.

## ما أحتاجه للمتابعة

- المطلوب حاليًا: رابط API القديم للإنتاج أو مصدر الخادم، إعداد iOS إذا كان التطبيق سيستخدم Firebase على iOS، وتمكين خدمات Firebase المطلوبة من Console.
- معرّف المشروع وإعداد Android تم استلامهما ومطابقتهما مع `com.dardshti.app`. لم تُرسل مفاتيح حساب خدمة أو كلمات مرور.

## فحص الإصدار السابق

في الحزمة السابقة تم ضبط `pubspec.yaml` على `1.4.0+5` وتوثيق هوية Android الحالية. أضيف Firebase Core لـAndroid وWeb وتم تحديث lockfile. نجح `flutter test` والتحليل المخصص لملفي التهيئة؛ أما التحليل الشامل فيعرض 27 ملاحظة أسلوبية في واجهات قديمة لم تُعدّل. لا يتوفر Android SDK لبناء APK. Firebase Auth/Firestore/Functions/Storage وبيانات iOS لا تزال غير مهيأة.
