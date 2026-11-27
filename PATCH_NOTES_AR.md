# ملاحظات التعديل

- إزالة ميزة منع/اكتشاف تسجيل الشاشة بالكامل من Flutter وAndroid.
- حذف صلاحية `DETECT_SCREEN_RECORDING` وعدم استخدام `FLAG_SECURE` أو Screen Recording Callback.
- إعادة `MainActivity` إلى `FlutterActivity` عادي؛ لذلك لا يقيّد التطبيق تسجيل الشاشة أو لقطات الشاشة على أي إصدار Android.
- إصلاح التعامل مع `codeDoc` في معاملتي تفعيل أكواد المواد الجامعية والدورات التدريبية: استخراج `externalCodeRef` محلياً والتحقق من وجوده قبل تمريره إلى `transaction.get` و`transaction.update`.

## التحقق

- تم فحص عدم بقاء مراجع ميزة تسجيل الشاشة في ملفات المصدر.
- تم فحص موضعي `externalCodeRef` والتأكد من عدم استخدام `codeDoc.reference` مباشرة داخل معاملتي التفعيل.
- تم التحقق من سلامة ملف ZIP بعد إنشائه.
- لم يتوفر Flutter/Dart SDK في بيئة التعديل، لذلك لم يتم تشغيل `flutter analyze` أو `flutter test` أو `flutter build apk`.
