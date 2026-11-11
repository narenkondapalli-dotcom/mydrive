plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.biolynk.mydrive"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.biolynk.mydrive"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }
    buildTypes {
        release { isMinifyEnabled = false }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/sharedAssets"))
}

// Copy the shared car catalogue (single source of truth for iOS + Android) into app assets.
val copySharedAssets by tasks.registering(Copy::class) {
    from(rootProject.file("../shared/car-catalog.json"))
    from(rootProject.file("../shared/cars")) { into("cars") }
    from(rootProject.file("../shared/briefing/greetings.json")) { into("briefing") }
    from(rootProject.file("../shared/sounds/welcome")) { include("*.mp3"); into("sounds/welcome") }
    into(layout.buildDirectory.dir("generated/sharedAssets"))
}
tasks.named("preBuild") { dependsOn(copySharedAssets) }

dependencies {
    val media3 = "1.6.1"
    implementation("androidx.media3:media3-exoplayer:$media3")
    implementation("androidx.media3:media3-session:$media3")
    implementation("androidx.car.app:app:1.7.0")
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")
    implementation(platform("androidx.compose:compose-bom:2025.04.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
