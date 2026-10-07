plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.arroz.user"
    
    // Naka-set sa 36 para sa geolocator at url_launcher
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // I-enable ang Core Library Desugaring para sa flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.arroz.user"

        // Siguraduhing kahit papaano ay minSdk = 21 para sa MultiDex / Notifications
        minSdk = flutter.minSdkVersion
        
        // Naka-set sa 36 para maging tugma ang runtime behavior
        targetSdk = 36

        versionCode = 2
        versionName = "1.1"

        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Kinakailangan para sa Desugaring support ng Java 8+ features sa Kotlin DSL
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}