import java.util.Base64

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Mirrors bool.fromEnvironment("USE_FIREBASE_EMULATOR") in
// lib/core/firebase/app_firebase.dart. The Flutter tool passes --dart-define
// values as -Pdart-defines=<base64>,<base64>,...
val useFirebaseEmulator: Boolean =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotEmpty() }
        ?.map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        ?.contains("USE_FIREBASE_EMULATOR=true")
        ?: false

android {
    namespace = "com.example.rafiq_academy"
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
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Each flavor's applicationId must match an Android app registered in
    // that flavor's Firebase project, or the google-services plugin fails
    // the build. dev keeps the ID registered in rafiq-academy until
    // com.basmaacademy.app.dev is registered there. staging and prod have no
    // src/<flavor>/google-services.json yet, so their builds stop at that
    // step instead of falling back to the dev project.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationId = "com.example.rafiq_academy"
            resValue("string", "app_name", "بصمة (تطوير)")
        }
        create("staging") {
            dimension = "env"
            applicationId = "com.basmaacademy.app.staging"
            resValue("string", "app_name", "بصمة (تجريبي)")
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.basmaacademy.app"
            resValue("string", "app_name", "بصمة")
        }
    }

    buildTypes {
        debug {
            // Native FCM auto-init runs at process start, before Dart, against
            // the project in this variant's google-services.json (dev:
            // rafiq-academy).
            manifestPlaceholders["firebaseMessagingAutoInitEnabled"] =
                (!useFirebaseEmulator).toString()
        }
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
