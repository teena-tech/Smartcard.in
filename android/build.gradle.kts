allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
    configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "io.flutter" && requested.name.startsWith("flutter_embedding")) {
                    useVersion("1.0.0-9161402dc0e134b3fb5adee5046b6e84b1a5e1c1")
                }
            }
        }
    }
}

subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
                defaultConfig {
                    ndk {
                        abiFilters.clear()
                        abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
                    }
                }
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        if (plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            extensions.findByType(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java)?.apply {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    project.plugins.withId("com.android.library") {
        val androidExtension = project.extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidExtension.namespace.isNullOrEmpty()) {
            androidExtension.namespace = "com.example.${project.name.replace("-", "_")}"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
