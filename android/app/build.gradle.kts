import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "se.butlery.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "se.butlery.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdkVersion(24)                          // Updated to 24 for Flutter compatibility
        targetSdk = 36                             // Latest SDK for Android 16 compatibility
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // `prod` is the store app on butlery-prod. `staging` installs beside it
    // and talks to butlery-app-staging; build it with
    // `--flavor staging --dart-define=ENV=staging` (lib/core/bootstrap/firebase_env.dart).
    // Each flavor's google-services.json: prod's at android/app/, staging's
    // at android/app/src/staging/. Both flavors sign with the release config.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            isDefault = true
            manifestPlaceholders["authLinkHost"] = "butlery-prod.firebaseapp.com"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            manifestPlaceholders["authLinkHost"] = "butlery-app-staging.firebaseapp.com"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else if (System.getenv("CI") == "true") {
                // CI without a keystore would silently ship a debug-signed AAB,
                // which Play Console rejects. Fail loudly instead.
                throw GradleException(
                    "Release build in CI requires android/key.properties. " +
                    "Ensure KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_PASSWORD, " +
                    "KEY_ALIAS GitHub Actions secrets are configured."
                )
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// A build without --flavor (a plain `flutter run`) must stay production, as it
// was before flavors existed. Gradle's `assembleDebug` would build both
// flavors, and the staging one has no google-services.json outside CI, so only
// prod is built then, and its APK is also copied to the unflavored name the
// Flutter tool looks for.
val flavorRequested = gradle.startParameter.taskNames.any {
    Regex("(?i)(prod|staging)").containsMatchIn(it)
}

if (!flavorRequested) {
    androidComponents {
        beforeVariants(selector().withFlavor("env" to "staging")) { it.enable = false }
    }
    tasks.matching { it.name in setOf("assembleDebug", "assembleProfile", "assembleRelease") }
        .configureEach {
            val mode = name.removePrefix("assemble").lowercase()
            val apkDir = layout.buildDirectory.dir("outputs/flutter-apk")
            doLast {
                val dir = apkDir.get().asFile
                val prodApk = dir.resolve("app-prod-$mode.apk")
                if (prodApk.exists()) prodApk.copyTo(dir.resolve("app-$mode.apk"), overwrite = true)
            }
        }
}

// firebase_env.dart throws at startup on an ENV its flavor does not expect, so
// a release with the wrong ENV installs fine and then cannot open. Refuse it
// here instead. Flutter passes defines as base64 entries, file ones first, so
// the last ENV is the one the app sees.
val releaseTasks = gradle.startParameter.taskNames.filter { it.contains("Release", ignoreCase = true) }
if (releaseTasks.isNotEmpty()) {
    val dartEnv = (findProperty("dart-defines") as String?).orEmpty()
        .split(",").filter { it.isNotBlank() }
        .map { String(Base64.getDecoder().decode(it)) }
        .lastOrNull { it.startsWith("ENV=") }?.removePrefix("ENV=") ?: ""
    for (task in releaseTasks) {
        val staging = task.contains("staging", ignoreCase = true)
        val allowed = if (staging) setOf("staging") else setOf("", "production")
        if (dartEnv !in allowed) {
            throw GradleException(
                "$task: ENV=\"$dartEnv\" does not match the " +
                (if (staging) "staging" else "prod") + " flavor (expected " +
                allowed.joinToString(" or ") { if (it.isEmpty()) "no ENV" else it } +
                "). A local .env is the developer one; release bundles come from CI."
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.gms:play-services-base:18.5.0")
    implementation("com.google.android.gms:play-services-auth:21.2.0")
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}
