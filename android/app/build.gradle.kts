import java.util.Properties
import java.io.FileInputStream
import de.undercouch.gradle.tasks.download.Download

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.enjaz.busguide"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    // kotlinOptions { jvmTarget = "17" } - Removed due to Kotlin DSL update

    defaultConfig {
        applicationId = "com.enjaz.busguide"
        minSdk = 24
        targetSdk = 36
        versionCode = 35
        versionName = "1.0.27"
    }

    signingConfigs {
        val storeFilePath = keystoreProperties["storeFile"] as? String
        if (storeFilePath != null && storeFilePath.isNotEmpty()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as? String
                keyPassword = keystoreProperties["keyPassword"] as? String
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as? String
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (signingConfigs.findByName("release") != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("net.bytebuddy:byte-buddy:1.14.10")

    // Kotlin
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.24")

    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.2.0"))

    // Firebase
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")

    // Google Services
    implementation("com.google.android.gms:play-services-maps:18.1.0")
    implementation("com.google.android.gms:play-services-location:21.0.1")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
}

/* ================== KTLINT ================== */

val ktlintVersion = "1.8.0"
val ktlintBin = file("$rootDir/ktlint")
val ktlintDownloadUrl =
    "https://github.com/pinterest/ktlint/releases/download/$ktlintVersion/ktlint"

tasks.register<Download>("downloadKtlint") {
    src(ktlintDownloadUrl)
    dest(ktlintBin)
    onlyIfModified(true)
}

tasks.register<Exec>("ktlintCheck") {
    dependsOn("downloadKtlint")
    group = "verification"
    description = "Check Kotlin code style."
    workingDir = projectDir
    commandLine("java", "-jar", ktlintBin.absolutePath, "src/**/*.kt")
}

tasks.register<Exec>("ktlintFormat") {
    dependsOn("downloadKtlint")
    group = "formatting"
    description = "Fix Kotlin code style deviations."
    workingDir = projectDir
    commandLine("java", "-jar", ktlintBin.absolutePath, "-F", "src/**/*.kt")
}

tasks.register<Delete>("cleanKtlint") {
    delete(ktlintBin)
}

kotlin {
    jvmToolchain(17)
}