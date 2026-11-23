// droid Phone: mirror and control an Android phone (scrcpy over USB or
// Wi-Fi ADB), pair it with a QR code, and drop files onto it.
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.compose)
    alias(libs.plugins.compose.compiler)
    application
}

kotlin {
    jvmToolchain(libs.versions.jvm.get().toInt())
}

dependencies {
    implementation(project(":common"))
    implementation(compose.desktop.currentOs)
    implementation(compose.materialIconsExtended)
    implementation(libs.zxing.core)
    testImplementation(kotlin("test"))
}

application {
    mainClass = "droid.phone.MainKt"
    applicationName = "droid-phone"
    applicationDefaultJvmArgs = listOf("--enable-native-access=ALL-UNNAMED")
}

tasks.test {
    useJUnitPlatform()
}
