plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ใช้ในโมดูล app ถูกแล้ว
}

android {
    namespace = "com.example.finalproject"          // ⚠ เปลี่ยนให้ตรงแพ็กเกจจริง + Firebase Console
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.finalproject"  // ⚠ ให้ตรง Firebase Console
        // google_maps_flutter ใช้ minSdk ≥ 21; คุณตั้ง 23 ก็โอเค
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // ถ้าใช้รูป vector เก่า ๆ
        // vectorDrawables.useSupportLibrary = true
    }

    // ใช้ Java/Kotlin 11 ก็เพียงพอสำหรับ FlutterFire + Maps
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        debug {
            // maps + firebase ไม่ต้อง minify ตอน dev
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // ชั่วคราวเซ็นด้วย debug ให้ build/run ได้
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            // จะเปิด R8 จริง ให้ใส่ proguard files เพิ่มเอง
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }

    // กันบางเคสซ้ำไฟล์ใบอนุญาตจาก lib ต่าง ๆ
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/LICENSE*",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/ASL2.0"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ปล่อยให้ Flutter/FlutterFire จัดการ dependency หลัก
    // ถ้าเจอ 64K method ให้เพิ่ม multidex (คุณเปิด multiDexEnabled แล้ว)
    // implementation("androidx.multidex:multidex:2.0.1")
}
