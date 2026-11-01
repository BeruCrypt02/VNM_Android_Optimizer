plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val ksPath: String? = System.getenv("KEYSTORE_FILE")
val hasKeystore = ksPath != null && file(ksPath).exists()

android {
    namespace = "com.mkvenompro.optimizer"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.mkvenompro.optimizer"
        minSdk = 26
        targetSdk = 34
        versionCode = 5
        versionName = "1.3.0"
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                storeFile = file(ksPath!!)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = if (hasKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    androidResources {
        // keep the engine scripts byte-for-byte
        noCompress += listOf("sh", "conf", "txt", "prop", "zip")
    }
}

dependencies {
    implementation("androidx.webkit:webkit:1.11.0")
    implementation("dev.rikka.shizuku:api:13.1.5")
    implementation("dev.rikka.shizuku:provider:13.1.5")
}
