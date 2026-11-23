plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.compose) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}

// Every app shares droid's version (droid.toml's [release] version, kept in
// step by scripts/release.main.kts).
allprojects {
    version = providers.gradleProperty("version").get()
    group = "io.github.mmaachado.droid"
}
