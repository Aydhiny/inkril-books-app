plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.inkril_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.inkril_mobile"
        minSdk = flutter.minSdkVersion // flutter_secure_storage v9 needs EncryptedSharedPreferences (API 23+)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        // ── Debug ─────────────────────────────────────────────────────────────
        // Include x86_64 for emulator support. All plugins including flutter_pdfview
        // ship x86_64 native libs (libjniPdfium, libmodpdfium, etc. are all present
        // in the merged x86_64 lib dir). API 37 emulators have no Houdini ARM
        // translation so ARM-only APKs crash; x86_64 native libs are required.
        getByName("debug") {
            ndk {
                abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
            }
        }

        // ── Release ───────────────────────────────────────────────────────────
        // ARM-only for real devices — all Android phones are ARM, keeps APK slim.
        release {
            ndk {
                abiFilters += listOf("armeabi-v7a", "arm64-v8a")
            }
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
