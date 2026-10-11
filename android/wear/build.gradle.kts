import java.util.Properties

// Companion app for Wear OS watches: it shows the day of the phone app and
// adds its products. The phone app stays the only source of truth.
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Version of the phone app, "1.2.3+45" in pubspec.yaml: the watch app has the
// same name, and its build number plus an offset as version code, as Google
// Play needs a different one for each app bundle.
val pubspecVersion = rootProject.file("../pubspec.yaml").readLines()
    .first { it.startsWith("version:") }
    .substringAfter(':')
    .trim()
val versionCodeOffset = providers.gradleProperty("wear.versionCodeOffset").get().toInt()

// Same signing key as the phone app, described in android/key.properties
// (never committed): Google Play services only link apps signed alike.
// Without it, release builds fall back to the debug key.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "arbitro.android.protein_calculator.wear"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // The same as the phone app: the two apps form one Google Play app.
        applicationId = "arbitro.android.protein_calculator"
        // Wear OS 3.
        minSdk = 30
        targetSdk = 36
        versionCode = versionCodeOffset + pubspecVersion.substringAfter('+').toInt()
        versionName = pubspecVersion.substringBefore('+')
    }

    signingConfigs {
        if (!keyProperties.isEmpty) {
            create("release") {
                // A relative path is read from android/app, as for the phone app.
                storeFile = project(":app").file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        compose = true
    }

    // The fonts of the phone app, and their licenses.
    sourceSets["main"].assets.srcDir("../../assets/fonts")
}

// The Flutter tool builds the phone app with tasks run in every project
// (assembleDebug, bundleRelease...), always passing -Ptarget. The watch app
// stays out of those builds: it is only built by its own tasks, such as
// :wear:assembleDebug.
if (providers.gradleProperty("target").isPresent) {
    tasks.configureEach { enabled = false }
}

dependencies {
    implementation(project(":wear:protocol"))
    implementation(platform(libs.compose.bom))
    implementation(libs.activity.compose)
    implementation(libs.complications.data.source)
    implementation(libs.compose.ui)
    implementation(libs.coroutines.play.services)
    implementation(libs.datastore.preferences)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.play.services.wearable)
    implementation(libs.protolayout)
    implementation(libs.protolayout.expression)
    implementation(libs.protolayout.material3)
    implementation(libs.tiles)
    implementation(libs.wear.compose.foundation)
    implementation(libs.wear.compose.material3)
    implementation(libs.wear.compose.navigation)
    implementation(libs.wear.input)
    implementation(libs.work.runtime)
    testImplementation(kotlin("test-junit"))
}
