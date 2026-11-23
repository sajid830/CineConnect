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
    val setCompileSdk: (Project) -> Unit = { p ->
        val android = p.extensions.findByName("android")
        if (android != null) {
            try {
                val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                method.invoke(android, 36)
                println("Set compileSdkVersion(36) on ${p.name}")
            } catch (_: Exception) {
                try {
                    val method = android.javaClass.getMethod("setCompileSdk", Integer::class.java)
                    method.invoke(android, 36)
                    println("Set setCompileSdk(36) on ${p.name}")
                } catch (_: Exception) {}
            }
        }
    }
    if (project.state.executed) {
        setCompileSdk(project)
    } else {
        project.afterEvaluate { setCompileSdk(project) }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
