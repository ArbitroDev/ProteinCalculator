// Android code of the link with the watch app. Part of the Gradle build of
// the app (android/), whose watch messages it uses.
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "arbitro.android.protein_calculator.watch_link"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
    }
}

dependencies {
    implementation(project(":wear:protocol"))
    implementation(libs.play.services.wearable)
}
