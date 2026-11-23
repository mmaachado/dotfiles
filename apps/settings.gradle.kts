// droid's Kotlin apps: normal app windows written with Compose Multiplatform
// (Material 3). The shell itself stays QML (home/.config/quickshell/kshell).
rootProject.name = "droid-apps"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
        google()
    }
}

plugins {
    // Downloads the JDK the toolchain asks for if it isn't installed.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
        google()
    }
}

include(":common")
