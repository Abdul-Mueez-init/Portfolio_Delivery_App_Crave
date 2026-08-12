import java.util.Properties
import java.io.FileInputStream

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.crave"
    // FIX: was `flutter.compileSdkVersion`, which resolved to
    // android-33 on this Flutter install — too old for
    // geocoding_android and several of its transitive androidx deps
    // (fragment, window, activity, lifecycle-*, core-ktx, etc.), all
    // of which require compileSdk >= 34. Pinned explicitly instead of
    // trusting the Flutter tool's default, since that default clearly
    // isn't tracking current androidx requirements on this setup.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.crave"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // FIX: pinned alongside compileSdk for the same reason —
        // targetSdk should track compileSdk, not fall back to a
        // stale flutter.targetSdkVersion default.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // SECURITY FIX: Maps API key no longer hardcoded in the manifest.
        // It's read from android/local.properties (gitignored) at build
        // time and injected here, then referenced in AndroidManifest.xml
        // as ${MAPS_API_KEY}. See local.properties.example for the format.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
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