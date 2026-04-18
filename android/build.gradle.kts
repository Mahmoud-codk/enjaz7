import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.10")
        classpath("de.undercouch:gradle-download-task:5.6.0")
        classpath("com.google.gms:google-services:4.4.3")
    }
}

// تغيير مكان build directory إلى مجلد خارجي
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
