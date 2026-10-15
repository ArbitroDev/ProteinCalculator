// Android code of the link with the watch app. Part of the Gradle build of
// the app (android/), whose watch messages it uses.
plugins {
    // Kotlin itself is applied by the Flutter Gradle plugin, as to every
    // Android project of the build.
    id("com.android.library")
}

android {
    namespace = "arbitro.android.protein_calculator.watch_link"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation(project(":wear:protocol"))
    implementation(libs.play.services.wearable)
}
