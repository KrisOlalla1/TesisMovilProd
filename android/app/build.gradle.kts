plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // equivalente a 'kotlin-android'
    // El plugin de Flutter debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "com.example.monitoreo_movil"

    // Usa las versiones que inyecta Flutter
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.example.monitoreo_movil"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ Java 17 + desugaring (para flutter_local_notifications)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    // ✅ Alinea el NDK con las libs (instala esta versión en SDK Manager)
    ndkVersion = "27.0.12077973"

    signingConfigs {
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            val keyProperties = Properties()
            if (keyPropertiesFile.exists()) {
                keyProperties.load(FileInputStream(keyPropertiesFile))
            }
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            storeFile = keyProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keyProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        // ⛔ Debug sin shrink para evitar errores de AAR/desugaring
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        // Release sin R8 (para usar con debug key)
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Necesario para core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Lo demás lo gestiona Flutter
}
