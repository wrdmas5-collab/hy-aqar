pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localPropertiesFile = file("local.properties")
            if (localPropertiesFile.exists()) {
                localPropertiesFile.inputStream().use { properties.load(it) }
                val flutterSdkPath = properties.getProperty("flutter.sdk")
                if (flutterSdkPath != null) {
                    flutterSdkPath
                } else {
                    throw GradleException("flutter.sdk not set in local.properties")
                }
            } else {
                // Fallback: try to get from environment variable or use default location
                val envFlutterSdk = System.getenv("FLUTTER_SDK")
                if (envFlutterSdk != null) {
                    envFlutterSdk
                } else {
                    throw GradleException("local.properties not found and FLUTTER_SDK env var not set")
                }
            }
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")
