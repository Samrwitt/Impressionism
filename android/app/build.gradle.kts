plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.impressionism.app.impressionism_app"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.impressionism.app.impressionism_app"
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            excludes += setOf(
                "**/libtensorflowlite_gpu_jni.so",
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
            )
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

configurations.all {
    exclude(group = "org.tensorflow", module = "tensorflow-lite-gpu")
    resolutionStrategy.eachDependency {
        if (requested.group == "org.tensorflow" &&
            (requested.name == "tensorflow-lite" ||
                requested.name == "tensorflow-lite-api" ||
                requested.name == "tensorflow-lite-gpu-api")
        ) {
            useVersion("2.16.1")
        }
    }
}
