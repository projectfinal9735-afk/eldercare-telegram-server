import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // สำหรับ Firebase google-services (ไป apply ใน :app อีกที)
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ย้าย build output ไปรวมที่โฟลเดอร์ ../../build (ตามที่คุณตั้งใจ)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    // ให้แต่ละ module ไปอยู่ในโฟลเดอร์ build แยกตามชื่อโปรเจกต์
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    layout.buildDirectory.set(newSubprojectBuildDir)
}

// Flutter มักต้องพึ่ง evaluation ของ :app ก่อนบางครั้ง
subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
