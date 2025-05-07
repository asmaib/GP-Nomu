plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // يجب أن يكون بعد Android و Kotlin
}

android {
    namespace = "com.example.flutter_application_2"
    compileSdk = 35 // استخدم أحدث نسخة لديك

    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.flutter_application_2"
        minSdk = 23
        targetSdk = 35// استخدم نسخة متوافقة
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // غيّره إذا كنت بحاجة إلى توقيع خاص
        }
    }
}

flutter {
    source = "../.."
}
