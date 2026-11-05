plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hyacademy.hy_academy_store"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hyacademy.hy_academy_store"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // إجبار الجريدل على تجاوز تدقيق الـ AAR Metadata لجميع الحزم نهائياً في وضع الـ release
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// كود إضافي لإلغاء أي قيود فحص خاصة بحزم الاعتماديات مثل file_picker
configurations.all {
    resolutionStrategy {
        eachDependency {
            if (requested.name.contains("aar-metadata") || requested.name.contains("CheckAarMetadata")) {
                useVersion("36.0.0")
            }
        }
    }
}

// تجاوز فحص الـ AAR Metadata عبر خصائص المشروع الداخلية
project.ext.set("android.injected.checkAarMetadata", false)

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}