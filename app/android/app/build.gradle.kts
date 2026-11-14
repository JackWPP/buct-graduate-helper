import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// 只允许在明确放行时产出 debug 签名的 release 包，用于本机冒烟。
// 日常开发仍应使用 app/android/key.properties 的正式 keystore。
val allowDebugReleaseSigning =
    (project.findProperty("allowDebugReleaseSigning") as String?)?.toBoolean() ?: false

android {
    namespace = "edu.buct.graduate.huayan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "edu.buct.graduate.huayan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 正式发布必须提供 app/android/key.properties；缺省时只在显式放行的情况下
            // 回退 debug 签名，否则 release 任务会在下面的 taskGraph 校验中失败。
            signingConfig = when {
                keystorePropertiesFile.exists() -> signingConfigs.getByName("release")
                allowDebugReleaseSigning -> {
                    logger.warn(
                        "key.properties not found: release APK is signed with the debug key " +
                            "because allowDebugReleaseSigning=true"
                    )
                    signingConfigs.getByName("debug")
                }
                else -> signingConfigs.getByName("debug")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val hasReleaseTask = allTasks.any { it.name.contains("release", ignoreCase = true) }
    if (hasReleaseTask && !keystorePropertiesFile.exists() && !allowDebugReleaseSigning) {
        throw GradleException(
            "Release signing is not configured. Create app/android/key.properties " +
                "with a release keystore, or set " +
                "ORG_GRADLE_PROJECT_allowDebugReleaseSigning=true for a debug-signed " +
                "local test build."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
