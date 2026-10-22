import java.util.Base64
import java.util.Properties

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

// Play upload key for prod release builds. Read from android/key.properties
// (git-ignored; storeFile is relative to android/app or absolute) or, when that
// file is absent, from the CM_KEYSTORE_PATH / CM_KEYSTORE_PASSWORD /
// CM_KEY_ALIAS / CM_KEY_PASSWORD variables that Codemagic's Android code
// signing sets. The keystore and its passwords are never committed.
val keystorePropertiesFile: File = rootProject.file("key.properties")
val uploadKey: Map<String, String?> =
    if (keystorePropertiesFile.exists()) {
        val properties = Properties()
        keystorePropertiesFile.inputStream().use { properties.load(it) }
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .associateWith { properties.getProperty(it) }
    } else {
        mapOf(
            "storeFile" to System.getenv("CM_KEYSTORE_PATH"),
            "storePassword" to System.getenv("CM_KEYSTORE_PASSWORD"),
            "keyAlias" to System.getenv("CM_KEY_ALIAS"),
            "keyPassword" to System.getenv("CM_KEY_PASSWORD"),
        )
    }
val hasUploadKey: Boolean = uploadKey.values.all { !it.isNullOrBlank() }

// A prod release is never signed with the debug key: without an upload key the
// build stops here instead of producing a debug-signed or unsigned artifact.
// Only artifact tasks are matched; setup tasks such as preProdReleaseBuild
// also appear in other variants' task graphs.
val prodReleaseArtifactTask = Regex("^(assemble|bundle|package|install)ProdRelease.*")
gradle.taskGraph.whenReady {
    if (!hasUploadKey && allTasks.any { prodReleaseArtifactTask.matches(it.name) }) {
        throw GradleException(
            "Prod release builds need the Play upload key: add android/key.properties " +
                "(storeFile, storePassword, keyAlias, keyPassword) or set the CM_KEYSTORE_* " +
                "variables. See docs/production/RELEASE_PLATFORM_SETUP.md."
        )
    }
}

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

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(uploadKey.getValue("storeFile")!!)
                storePassword = uploadKey.getValue("storePassword")
                keyAlias = uploadKey.getValue("keyAlias")
                keyPassword = uploadKey.getValue("keyPassword")
            }
        }
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
            // Local and test builds only; never uploaded to a store.
            signingConfig = signingConfigs.getByName("debug")
        }
        create("staging") {
            dimension = "env"
            applicationId = "com.basmaacademy.app.staging"
            resValue("string", "app_name", "بصمة (تجريبي)")
            signingConfig = signingConfigs.getByName("debug")
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.basmaacademy.app"
            resValue("string", "app_name", "بصمة")
            if (hasUploadKey) signingConfig = signingConfigs.getByName("upload")
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
        // release sets no signingConfig, so each flavor's applies: debug for
        // dev and staging, the upload key for prod.
        release {
        }
    }
}

flutter {
    source = "../.."
}
