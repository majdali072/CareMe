plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.careme"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.careme"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps API key is injected into AndroidManifest.xml via the
        // ${MAPS_API_KEY} manifest placeholder. Override at runtime with:
        //   flutter run --dart-define=GOOGLE_MAPS_API_KEY=xxx \
        //               -Pmaps_api_key=xxx
        manifestPlaceholders["MAPS_API_KEY"] =
            (project.findProperty("maps_api_key") as String?)
                ?: "AIzaSyDxH73xrf5oJCGEzJk5R2VAg3NvbpraICQ"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// After a release build, drop a CareMe.apk copy next to the original so
// `flutter build apk --release` always emits build/app/outputs/flutter-apk/CareMe.apk.
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val gradleApk = file("${layout.buildDirectory.get()}/outputs/apk/release/app-release.apk")
        if (!gradleApk.exists()) return@doLast
        gradleApk.copyTo(File(gradleApk.parentFile, "CareMe.apk"), overwrite = true)
        val flutterApkDir = file("${rootProject.projectDir}/../build/app/outputs/flutter-apk")
        flutterApkDir.mkdirs()
        gradleApk.copyTo(File(flutterApkDir, "CareMe.apk"), overwrite = true)
    }
}
