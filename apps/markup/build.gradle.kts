// droid Markup: annotate a screenshot (pen, arrow, shapes, text, highlight,
// pixelate, crop), opened from KShell's screenshot thumbnail.
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
    testImplementation(kotlin("test"))
}

application {
    mainClass = "droid.markup.MainKt"
    applicationName = "droid-markup"
    // Skia (skiko) loads its native library; allow it without a warning.
    applicationDefaultJvmArgs = listOf("--enable-native-access=ALL-UNNAMED")
}

tasks.test {
    useJUnitPlatform()
    systemProperty("java.awt.headless", "true")
}
