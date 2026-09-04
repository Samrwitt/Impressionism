allprojects {
    repositories {
        google()
        mavenCentral()
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

fun Project.forceAndroidCompileSdk(version: Int) {
    val android = extensions.findByName("android") ?: return
    try {
        val method = android.javaClass.methods.firstOrNull {
            it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1
        }
        if (method != null) {
            method.invoke(android, version)
            return
        }
    } catch (_: Exception) {
    }
    try {
        val method = android.javaClass.methods.firstOrNull {
            it.name == "setCompileSdk" && it.parameterTypes.size == 1
        }
        method?.invoke(android, version)
    } catch (_: Exception) {
    }
}

subprojects {
    val configureJvm = {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
        forceAndroidCompileSdk(36)
    }
    if (state.executed) {
        configureJvm()
    } else {
        afterEvaluate { configureJvm() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
