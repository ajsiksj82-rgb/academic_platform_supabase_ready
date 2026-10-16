# المنصة الأكاديمية الرقمية — جامعة الحديدة / كلية التربية زبيد

هذا المشروع مبني على ملفات Flutter الموجودة في الأرشيف الأصلي مع الحفاظ على التصميم العربي وخط Cairo والأيقونة وواجهات المنصة. أُضيفت إليه طبقة مصادقة حقيقية باستخدام Supabase، وقراءة صلاحية المستخدم من جدول `profiles`، وشاشة إدارية لإنشاء الحسابات عبر Edge Function محمية. لم يعد تسجيل الدخول التجريبي مقبولًا.

## ما تم ربطه في هذه النسخة

- تسجيل الدخول بالبريد الإلكتروني وكلمة المرور عبر Supabase Auth.
- تحميل الاسم والصلاحية وحالة الحساب من `public.profiles`؛ لا يختار المستخدم صلاحية حسابه بنفسه.
- منع الدخول إذا لم يوجد ملف مستخدم أو كان الحساب موقوفًا.
- تسجيل الخروج من جلسة Supabase.
- شاشة «إدارة المستخدمين» لحساب الإدارة لإنشاء حسابات الطلاب والمدرسين ورئيس القسم والإدارة.
- مخطط تأسيسي في `supabase/schema.sql` للجداول الأكاديمية الأساسية وسياسات Row Level Security.
- دالة `supabase/functions/create-user` لإنشاء المستخدم باستخدام مفتاح الخدمة داخل الخادم فقط.

**مهم:** بقية صفحات المحاضرات والواجبات والحضور والتقارير ما زالت تحتاج ربط عمليات القراءة والكتابة الفعلية بالجداول؛ لا تعتبر جميع خدمات الواجهات مكتملة لمجرد وجود صفحاتها. يلزم أيضًا إعداد مشروع Supabase وتشغيل الاختبارات والبناء في بيئة Flutter.

## 1. إعداد Supabase

1. أنشئ مشروعًا في Supabase واحفظ **Project URL** و**anon/publishable key**.
2. افتح SQL Editor ونفّذ كامل الملف `supabase/schema.sql`.
3. من Authentication > Providers / Sign In، عطّل التسجيل العام للمستخدمين إن كان متاحًا في إعدادات مشروعك؛ إنشاء الحسابات يجب أن يكون من الإدارة فقط.
4. من Authentication > Users أنشئ أول مستخدم إدارة ببريد إلكتروني وكلمة مرور قوية.
5. انسخ UUID الخاص بالمستخدم، ثم نفّذ في SQL Editor بعد تعديل القيم:

```sql
insert into public.profiles (id, full_name, email, role, is_active)
values ('UUID-OF-FIRST-ADMIN', 'مدير المنصة', 'admin@example.com', 'admin', true);
```

يجب أن يطابق البريد المستخدم الذي أنشأته في Authentication، وأن تستبدل UUID والبريد والاسم بالقيم الحقيقية. لا تشارك كلمة المرور أو مفاتيح الخدمة.

## 2. نشر وظيفة إنشاء الحسابات

من جهاز مثبت عليه Supabase CLI ومسجل الدخول ومربوط بمشروعك، نفّذ من مجلد المشروع:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy create-user
```

تعتمد الوظيفة على متغيرات البيئة التي يوفّرها Supabase للدالة، ومنها `SUPABASE_URL` و`SUPABASE_ANON_KEY` و`SUPABASE_SERVICE_ROLE_KEY`. **لا تضع `service_role` في Flutter أو GitHub أو داخل APK.** تتحقق الدالة من جلسة الطالب/المستخدم، ثم تتأكد أن دوره `admin` قبل إنشاء الحساب.

## 3. تشغيل Flutter في Klencod IDE

افتح مجلد `academic_platform_flutter` الذي يحتوي على `pubspec.yaml`، ثم نفّذ:

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

استبدل القيم الوهمية بالقيم الفعلية من إعدادات مشروعك. لا تضع مفتاح `service_role` هنا. إن كانت Klencod IDE توفر حقولًا لمتغيرات البناء، استخدمها بدل كتابتها في سكربتات مشتركة.

## 4. بناء APK

```bash
flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

المسار المتوقع للملف:

`build/app/outputs/flutter-apk/app-release.apk`

لا ترفع APK مهيأ بمفاتيح مشروع شخص آخر. مفاتيح Supabase العامة مخصصة للتطبيق العميل، ويجب أن تحمي البيانات بسياسات RLS صحيحة.

## 5. قبل الاعتماد الفعلي

- شغّل `flutter analyze` و`flutter test` والبناء على بيئة Flutter فعلية؛ لا توجد نتيجة نجاح موثقة ضمن هذه الحزمة حتى الآن.
- راجع سياسات RLS بحسب الهيكل النهائي وصلاحيات الجامعة، وجرّب كل دور بحساب مستقل.
- اربط صفحات المحاضرات والواجبات والحضور والتسليمات والدرجات والشكاوى والإعلانات بعمليات قاعدة البيانات، وأضف Storage policies لملفات المحاضرات.
- راجع أسماء الجداول والحقول مع مخطط البحث النهائي قبل إدخال بيانات جامعية حقيقية.
