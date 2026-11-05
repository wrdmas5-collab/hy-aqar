plugins {
    id("com.android.application")
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
        applicationId = "com.hyacademy.hy_academy_store"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

configurations.all {
    resolutionStrategy {
        eachDependency {
            if (requested.name.contains("aar-metadata") || requested.name.contains("CheckAarMetadata")) {
                useVersion("36.0.0")
            }
        }
    }
}

project.ext.set("android.injected.checkAarMetadata", false)

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

subprojects {
    afterEvaluate { project ->
        project.tasks.matching { it.name.contains("CheckAarMetadata") }.configureEach {
            enabled = false
        }
    }
}