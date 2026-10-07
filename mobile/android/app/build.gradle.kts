import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Signing release: isi android/key.properties (storeFile, storePassword, keyAlias, keyPassword).
// File ini dan keystore diabaikan git. Build RILIS tanpa keystore GAGAL (tidak pernah memakai kunci debug), karena APK
// yang dikirim ke pengguna hanya bisa diperbarui bila selalu ditandatangani kunci yang sama. Lihat mobile/RELEASE.md.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.example.catu_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.catu_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // v2 + v3: v3 memungkinkan penggantian kunci di masa depan tanpa memaksa pengguna memasang ulang.
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) signingConfig = signingConfigs.getByName("release")
            isShrinkResources = false
            isMinifyEnabled = false
        }
    }
}

// Gagal lebih awal dan jelas bila build rilis diminta tanpa keystore.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { t -> t.name.contains("Release") && (t.name.startsWith("assemble") || t.name.startsWith("bundle") || t.name.startsWith("package")) }
    if (buildsRelease && !hasReleaseKeystore) {
        throw GradleException("Build rilis dibatalkan: android/key.properties (keystore rilis) belum ada. APK rilis tidak boleh memakai kunci debug. Lihat mobile/RELEASE.md.")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
