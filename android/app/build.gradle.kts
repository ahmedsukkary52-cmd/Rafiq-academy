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

// Personal review APK (-PbasmaReviewBuild=true): the dev debug build gets its
// own application ID so it installs beside an older dev build signed with a
// different debug key. Everything else about dev is unchanged.
val basmaReviewBuild: Boolean = project.findProperty("basmaReviewBuild") == "true"
val reviewApplicationIdSuffix = ".review"
val reviewManifestPath = "src/dev-review/AndroidManifest.xml"

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
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
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
            if (basmaReviewBuild) applicationIdSuffix = reviewApplicationIdSuffix
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
        create("trial") {
            dimension = "env"
            applicationId = "com.example.rafiq_academy"
            resValue("string", "app_name", "بصمة (تجربة الأكاديمية)")
            signingConfig = signingConfigs.getByName("debug")
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.basmaacademy.app"
            resValue("string", "app_name", "بصمة")
            if (hasUploadKey) signingConfig = signingConfigs.getByName("upload")
        }
    }

    if (basmaReviewBuild) {
        sourceSets.getByName("dev").manifest.srcFile(reviewManifestPath)
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
        // dev, staging and trial; the upload key for prod (when present).
        // Without an upload key, prod release artifact tasks fail in whenReady
        // instead of falling back to the debug key.
        release {
        }
    }
}

flutter {
    source = "../.."
}

// ---- Basma local-flavor isolation (Firebase Emulator only) ----
// dev and staging are LOCAL flavors: debug-only, USE_FIREBASE_EMULATOR=true
// required, and they must resolve ONLY their own fake
// src/<flavor>/google-services.json (project demo-rafiq-rules). The root
// android/app/google-services.json is preserved unchanged and must never be
// selected for a local variant. prod is not touched by these guards.
val localFlavors = setOf("dev", "staging")
val localEmulatorProjectId = "demo-rafiq-rules"
val localFlavorAppIds = mapOf(
    "dev" to "com.example.rafiq_academy",
    "staging" to "com.basmaacademy.app.staging",
)
val localArtifactTask = Regex("^(assemble|bundle|package|install)(Dev|Staging)(Debug|Profile|Release)$")
val trialArtifactTask = Regex("^(assemble|bundle|package|install)Trial(Debug|Profile|Release)$")
gradle.taskGraph.whenReady {
    val trial = allTasks.map { it.name }.filter { trialArtifactTask.matches(it) }
    if (trial.isNotEmpty() && useFirebaseEmulator) {
        throw GradleException(
            "Trial flavor connects to the real rafiq-academy Firebase project: " +
                "do not build with --dart-define=USE_FIREBASE_EMULATOR=true ($trial)."
        )
    }
    val local = allTasks.map { it.name }.filter { localArtifactTask.matches(it) }
    if (local.isNotEmpty()) {
        if (local.any { !it.endsWith("Debug") }) {
            throw GradleException(
                "Local flavors (dev, staging) are debug-only Firebase Emulator builds: $local"
            )
        }
        if (!useFirebaseEmulator) {
            throw GradleException(
                "Local flavors (dev, staging) require --dart-define=USE_FIREBASE_EMULATOR=true."
            )
        }
    }
    if (basmaReviewBuild && allTasks.any { it.name.matches(Regex("^(assemble|bundle|package|install)(Staging|Prod).*")) }) {
        throw GradleException("-PbasmaReviewBuild=true applies to the dev debug build only.")
    }
}
val googleServicesTask = Regex("^process(Dev|Staging)(Debug|Profile|Release)GoogleServices$")
tasks.configureEach {
    val match = googleServicesTask.find(name) ?: return@configureEach
    val flavor = match.groupValues[1].lowercase()
    val task = this
    doFirst {
        val file = project.file("src/$flavor/google-services.json")
        if (!file.isFile) {
            throw GradleException("Missing fake local config ${file.path} for flavor $flavor.")
        }
        val text = file.readText()
        val projectId = Regex("\"project_id\"\\s*:\\s*\"([^\"]+)\"").find(text)?.groupValues?.get(1)
        if (projectId != localEmulatorProjectId) {
            throw GradleException("$flavor must use $localEmulatorProjectId, got $projectId in ${file.path}.")
        }
        if (!text.contains("\"${localFlavorAppIds.getValue(flavor)}\"")) {
            throw GradleException("${file.path} does not register ${localFlavorAppIds.getValue(flavor)}.")
        }
        val reviewAppId = localFlavorAppIds.getValue(flavor) + reviewApplicationIdSuffix
        if (basmaReviewBuild && flavor == "dev" && !text.contains("\"$reviewAppId\"")) {
            throw GradleException("${file.path} does not register $reviewAppId.")
        }
    }
    doLast {
        val values = task.outputs.files.asFileTree.matching { include("**/values.xml") }.files
        if (values.isEmpty()) throw GradleException("$name produced no values.xml to verify.")
        values.forEach { xml ->
            val ids = Regex("name=\"project_id\"[^>]*>([^<]+)<").findAll(xml.readText()).map { it.groupValues[1] }.toList()
            if (ids != listOf(localEmulatorProjectId)) {
                throw GradleException("$name resolved project_id $ids in ${xml.path}; expected only $localEmulatorProjectId.")
            }
        }
    }
}
if (basmaReviewBuild) {
    tasks.matching { it.name == "processDevDebugMainManifest" }.configureEach {
        val task = this
        doLast {
            val merged = task.outputs.files.asFileTree
                .matching { include("**/AndroidManifest.xml") }.files
            if (merged.isEmpty()) throw GradleException("$name produced no merged manifest to verify.")
            merged.forEach { xml ->
                val text = xml.readText()
                fun metaFalse(key: String) = Regex(
                    "android:name=\"$key\"\\s+android:value=\"false\""
                ).containsMatchIn(text)
                if (text.contains("com.google.firebase.provider.FirebaseInitProvider") ||
                    !metaFalse("firebase_messaging_auto_init_enabled") ||
                    !metaFalse("firebase_messaging_notification_delegation_enabled")
                ) {
                    throw GradleException(
                        "Review manifest ${xml.path} must drop FirebaseInitProvider and keep FCM " +
                            "auto-init and notification delegation disabled."
                    )
                }
            }
        }
    }
}
androidComponents {
    onVariants(selector().all()) { variant ->
        if (variant.flavorName in localFlavors) {
            // Local flavors never auto-initialize FCM natively.
            variant.manifestPlaceholders.put("firebaseMessagingAutoInitEnabled", "false")
        }
    }
}
// ---- end Basma local-flavor isolation ----

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
