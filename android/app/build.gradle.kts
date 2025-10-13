plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")          // ✅ ใช้ id ของ Kotlin บน Kotlin DSL
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")        // ✅ apply ในโมดูลแอป
}

android {
    namespace = "com.example.finalproject"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }

    defaultConfig {
        applicationId = "com.example.finalproject"  // ✅ ต้องตรง Firebase Console
        minSdk = maxOf(23, flutter.minSdkVersion)   // ✅ อย่างน้อย 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        debug {
            // ✅ กัน error: shrinkResources ต้องปิดถ้าไม่ minify
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // ใช้ debug keystore ชั่วคราวให้ run ได้
            signingConfig = signingConfigs.getByName("debug")
            // ปิด shrink ทั้งคู่ (ค่อยเปิดทีหลังหากต้องการ)
            isMinifyEnabled = false
            isShrinkResources = false
            // ถ้าจะเปิดจริงให้ใส่ proguard files ด้วย:
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // เว้นว่าง ให้ FlutterFire จัดการ dependency เอง
}
