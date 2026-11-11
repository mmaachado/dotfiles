//! Apply a KShell theme to the whole desktop.
//!
//!     theme apply <id>   colour scheme, window decoration, Plasma style,
//!                        app style (Breeze or Kvantum blur), kitty, shell
//!     theme current      print the active theme id
//!     theme list         print the theme ids
//!
//! Themes are defined in config/themes.json. The shell reads the active theme
//! from ~/.local/state/kshell/theme.json (written here) to decide on blur.

use std::collections::HashMap;
use std::fmt::Write as _;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{Context, Result, bail};
use serde::Deserialize;
use zbus::Connection;

use crate::paths::{home, in_path, shell_dir, state_dir, write_atomic};

pub type Rgb = [u8; 3];

const NEGATIVE: Rgb = [218, 68, 83];
const NEUTRAL: Rgb = [246, 116, 0];
const POSITIVE: Rgb = [39, 174, 96];
const WHITE: Rgb = [255, 255, 255];

#[derive(Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Palette {
    pub window: Rgb,
    pub window_alt: Rgb,
    pub view: Rgb,
    pub view_alt: Rgb,
    pub button: Rgb,
    pub button_alt: Rgb,
    pub header: Rgb,
    pub header_inactive: Rgb,
    pub tooltip: Rgb,
    pub text: Rgb,
    pub text_inactive: Rgb,
    pub accent: Rgb,
}

#[derive(Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Theme {
    pub id: String,
    pub name: String,
    pub dark: bool,
    pub blur: bool,
    pub base: Option<String>,
    pub plasma_style: Option<String>,
    pub blur_strength: Option<u32>,
    pub app_translucency: Option<u32>,
    pub palette: Option<Palette>,
}

impl Theme {
    pub fn palette(&self) -> &Palette {
        self.palette.as_ref().expect("palette resolved in load()")
    }
}

#[derive(Deserialize)]
struct ThemesFile {
    themes: Vec<Theme>,
}

/// Load the themes; blur variants inherit their base palette.
pub fn load(file: &Path) -> Result<Vec<Theme>> {
    let text = std::fs::read_to_string(file).with_context(|| format!("reading {}", file.display()))?;
    let mut themes = serde_json::from_str::<ThemesFile>(&text)?.themes;
    let palettes: HashMap<String, Palette> =
        themes.iter().filter_map(|t| Some((t.id.clone(), t.palette.clone()?))).collect();
    for t in &mut themes {
        if t.palette.is_none() {
            let base = t.base.as_deref().with_context(|| format!("theme {} has no palette or base", t.id))?;
            t.palette = Some(palettes.get(base).with_context(|| format!("unknown base {base}"))?.clone());
        }
    }
    Ok(themes)
}

fn rgb(c: Rgb) -> String {
    format!("{},{},{}", c[0], c[1], c[2])
}

fn rgba(c: Rgb, a: u8) -> String {
    format!("{},{},{},{a}", c[0], c[1], c[2])
}

pub fn hexc(c: Rgb) -> String {
    format!("#{:02x}{:02x}{:02x}", c[0], c[1], c[2])
}

fn hexa(c: Rgb, a: u8) -> String {
    format!("#{a:02x}{:02x}{:02x}{:02x}", c[0], c[1], c[2])
}

fn camel(id: &str) -> String {
    id.split('-')
        .map(|p| {
            let mut c = p.chars();
            c.next().map(|f| f.to_uppercase().chain(c.flat_map(char::to_lowercase)).collect()).unwrap_or_default()
        })
        .collect::<Vec<String>>()
        .concat()
}

/// Blur themes share their base scheme: the colours are identical.
fn scheme_name(t: &Theme) -> String {
    format!("KShell{}", camel(t.base.as_deref().unwrap_or(&t.id)))
}

// ── KDE colour scheme ────────────────────────────────────────────────────────

type Group = Vec<(&'static str, String)>;

fn set(g: &mut Group, key: &str, value: String) {
    if let Some(e) = g.iter_mut().find(|(k, _)| *k == key) {
        e.1 = value;
    }
}

fn colour_scheme(t: &Theme) -> String {
    let p = t.palette();
    let (accent, text, inactive) = (p.accent, p.text, p.text_inactive);
    let group = |bg: Rgb, alt: Rgb, fg: Rgb| -> Group {
        vec![
            ("BackgroundNormal", rgb(bg)),
            ("BackgroundAlternate", rgb(alt)),
            ("ForegroundNormal", rgb(fg)),
            ("ForegroundInactive", rgb(inactive)),
            ("ForegroundActive", rgb(accent)),
            ("ForegroundLink", rgb(accent)),
            ("ForegroundVisited", rgb(inactive)),
            ("ForegroundNegative", rgb(NEGATIVE)),
            ("ForegroundNeutral", rgb(NEUTRAL)),
            ("ForegroundPositive", rgb(POSITIVE)),
            ("DecorationFocus", rgb(accent)),
            ("DecorationHover", rgb(accent)),
        ]
    };

    let mut header_inactive = group(p.header_inactive, p.window_alt, text);
    set(&mut header_inactive, "ForegroundNormal", rgba(text, 150));
    let mut selection = group(accent, accent, WHITE);
    set(&mut selection, "DecorationFocus", "255,255,255".into());
    set(&mut selection, "DecorationHover", "255,255,255".into());
    set(&mut selection, "ForegroundInactive", rgb(accent.map(|v| v.saturating_add(80))));

    let kv = |pairs: &[(&'static str, &str)]| -> Group { pairs.iter().map(|(k, v)| (*k, (*v).to_string())).collect() };
    let short_name = t.name.split_whitespace().last().unwrap_or(&t.name);
    let groups: Vec<(&str, Group)> = vec![
        ("Colors:Window", group(p.window, p.window_alt, text)),
        ("Colors:View", group(p.view, p.view_alt, text)),
        ("Colors:Button", group(p.button, p.button_alt, text)),
        ("Colors:Header", group(p.header, p.window_alt, text)),
        ("Colors:Header][Inactive", header_inactive),
        ("Colors:Tooltip", group(p.tooltip, p.window_alt, text)),
        ("Colors:Complementary", group(p.tooltip, p.window_alt, text)),
        ("Colors:Selection", selection),
        (
            "ColorEffects:Disabled",
            kv(&[
                ("ColorAmount", "0"),
                ("ColorEffect", "0"),
                ("ContrastAmount", "0.65"),
                ("ContrastEffect", "1"),
                ("IntensityAmount", "0.1"),
                ("IntensityEffect", "2"),
            ]),
        ),
        ("ColorEffects:Inactive", kv(&[("ChangeSelectionColor", "true"), ("Enable", "false")])),
        (
            "General",
            vec![
                ("ColorScheme", scheme_name(t)),
                ("Name", format!("KShell {short_name}")),
                ("shadeSortColumn", "true".into()),
            ],
        ),
        ("KDE", kv(&[("contrast", "4")])),
        (
            "WM",
            vec![
                ("activeBackground", rgb(p.header)),
                ("activeBlend", rgb(text)),
                ("activeForeground", rgb(text)),
                ("inactiveBackground", rgb(p.header_inactive)),
                ("inactiveBlend", rgb(inactive)),
                ("inactiveForeground", rgb(inactive)),
            ],
        ),
    ];

    let mut out = Vec::new();
    for (name, g) in groups {
        let mut s = format!("[{name}]\n");
        for (k, v) in g {
            let _ = writeln!(s, "{k}={v}");
        }
        out.push(s);
    }
    out.join("\n")
}

// ── Kvantum (translucent + blurred Qt apps) ──────────────────────────────────

fn kvantum_theme(t: &Theme, kvantum: &Path) -> Result<String> {
    let name = format!("KShell{}", camel(&t.id));
    let folder = kvantum.join(&name);
    std::fs::create_dir_all(&folder)?;
    let base_name = if t.dark { "KvFlat" } else { "KvFlatLight" }; // SVG graphics we reuse
    let svg = Path::new("/usr/share/Kvantum").join(base_name).join(format!("{base_name}.svg"));
    if svg.exists() {
        std::fs::copy(&svg, folder.join(format!("{name}.svg")))?;
    }
    std::fs::write(folder.join(format!("{name}.kvconfig")), kvantum_conf(t, base_name))?;
    Ok(name)
}

fn kvantum_conf(t: &Theme, base_name: &str) -> String {
    let p = t.palette();
    let translucency = t.app_translucency.unwrap_or(25);
    let (text, accent) = (p.text, p.accent);
    format!(
        "[%General]
author=KShell (generated by kshelld)
comment=Translucent, blurred windows for the KShell {theme} theme
inherits={base_name}
composite=true
translucent_windows=true
blurring=true
popup_blurring=true
reduce_window_opacity={translucency}
reduce_menu_opacity={menu}
menu_blur_radius=12
# let the blur show through Dolphin's file view and similar panes too
transparent_dolphin_view=true
transparent_pcmanfm_view=true
transparent_pcmanfm_sidepane=true
tooltip_blur_radius=8

[GeneralColors]
window.color={window}
base.color={view}
alt.base.color={view_alt}
button.color={button}
light.color={button_alt}
mid.light.color={window_alt}
dark.color={header_inactive}
mid.color={window_alt}
highlight.color={accent_hex}
inactive.highlight.color={accent_dim}
text.color={text_hex}
window.text.color={text_hex}
button.text.color={text_hex}
disabled.text.color={text_inactive}
tooltip.text.color={text_hex}
highlight.text.color=#ffffff
link.color={accent_hex}
link.visited.color={text_inactive}
progress.indicator.text.color={text_hex}
",
        theme = t.name,
        menu = translucency.saturating_sub(10).max(10),
        window = hexc(p.window),
        view = hexc(p.view),
        view_alt = hexc(p.view_alt),
        button = hexc(p.button),
        button_alt = hexc(p.button_alt),
        window_alt = hexc(p.window_alt),
        header_inactive = hexc(p.header_inactive),
        accent_hex = hexc(accent),
        accent_dim = hexa(accent, 0x99),
        text_hex = hexc(text),
        text_inactive = hexc(p.text_inactive),
    )
}

// ── kitty ────────────────────────────────────────────────────────────────────

const ANSI_DARK: [&str; 16] = [
    "#1d1f21", "#cc6666", "#b5bd68", "#f0c674", "#81a2be", "#b294bb", "#8abeb7", "#c5c8c6", "#666666", "#d54e53",
    "#b9ca4a", "#e7c547", "#7aa6da", "#c397d8", "#70c0b1", "#eaeaea",
];
const ANSI_LIGHT: [&str; 16] = [
    "#2b2b2b", "#c82829", "#718c00", "#b07d00", "#4271ae", "#8959a8", "#3e999f", "#8e908c", "#5f5f5f", "#c82829",
    "#5b7a00", "#a06a00", "#3465a4", "#75507b", "#06989a", "#4d4d4c",
];

fn kitty_conf(t: &Theme) -> String {
    let p = t.palette();
    let ansi = if t.dark { ANSI_DARK } else { ANSI_LIGHT };
    let mut s = format!(
        "# generated by KShell kshelld ({id})
background {view}
foreground {text}
cursor {text}
selection_background {accent}
selection_foreground #ffffff
active_tab_background {accent}
active_tab_foreground #ffffff
inactive_tab_background {window}
inactive_tab_foreground {inactive}
background_opacity {opacity}
background_blur {blur}
",
        id = t.id,
        view = hexc(p.view),
        text = hexc(p.text),
        accent = hexc(p.accent),
        window = hexc(p.window),
        inactive = hexc(p.text_inactive),
        opacity = if t.blur { "0.78" } else { "1.0" },
        blur = if t.blur { 32 } else { 0 },
    );
    for (i, c) in ansi.iter().enumerate() {
        let _ = writeln!(s, "color{i} {c}");
    }
    s
}

fn kitty_theme(t: &Theme) -> Result<()> {
    write_atomic(&state_dir().join("kitty-theme.conf"), &kitty_conf(t))?;
    exec(&["pkill", "-USR1", "-x", "kitty"]); // reload config
    Ok(())
}

// ── apply ────────────────────────────────────────────────────────────────────

fn exec(cmd: &[&str]) {
    let _ = Command::new(cmd[0]).args(&cmd[1..]).stdout(Stdio::null()).status();
}

fn kwrite(file: &str, group: &str, key: &str, value: Option<&str>) {
    let mut cmd = vec!["kwriteconfig6", "--file", file, "--group", group, "--key", key];
    cmd.push(value.unwrap_or("--delete"));
    exec(&cmd);
}

fn first_existing(dirs: &[PathBuf], name: &str) -> bool {
    dirs.iter().any(|d| d.join(name).is_dir())
}

async fn kwin(conn: &Connection, path: &str, iface: &str, method: &str, body: &(impl serde::Serialize + zbus::zvariant::DynamicType)) {
    if let Err(e) = conn.call_method(Some("org.kde.KWin"), path, Some(iface), method, body).await {
        eprintln!("kshelld: KWin {method}: {e}");
    }
}

async fn apply(t: &Theme) -> Result<()> {
    let home = home();
    let state = state_dir();
    let schemes = home.join(".local/share/color-schemes");
    let kvantum = home.join(".config/Kvantum");
    std::fs::create_dir_all(&state)?;
    std::fs::create_dir_all(&schemes)?;
    let conn = Connection::session().await?;

    // 1. colour scheme (also recolours GTK apps through Plasma's gtkconfig)
    let name = scheme_name(t);
    std::fs::write(schemes.join(format!("{name}.colors")), colour_scheme(t))?;
    exec(&["plasma-apply-colorscheme", &name]);

    // 2. window decoration: MacVentura aurorae if installed, else Breeze
    let aurorae = [home.join(".local/share/aurorae/themes"), "/usr/share/aurorae/themes".into()];
    let variant = if t.dark { "MacVentura-Dark" } else { "MacVentura-Light" };
    let (library, deco) = if first_existing(&aurorae, variant) {
        ("org.kde.kwin.aurorae.v2", format!("__aurorae__svg__{variant}"))
    } else {
        ("org.kde.breeze", "Breeze".into())
    };
    kwrite("kwinrc", "org.kde.kdecoration2", "library", Some(library));
    kwrite("kwinrc", "org.kde.kdecoration2", "theme", Some(&deco));
    kwin(&conn, "/KWin", "org.kde.KWin", "reconfigure", &()).await;

    // 3. Plasma style (OSDs, KRunner): "default" follows the colour scheme
    let themes = [home.join(".local/share/plasma/desktoptheme"), "/usr/share/plasma/desktoptheme".into()];
    let style = t.plasma_style.as_deref().filter(|s| first_existing(&themes, s)).unwrap_or("default");
    exec(&["plasma-apply-desktoptheme", style]);

    // 4. app style: Kvantum with translucency + blur for blur themes, Breeze otherwise
    let widget = if t.blur && in_path("kvantummanager") {
        let kv = kvantum_theme(t, &kvantum)?;
        kwrite(kvantum.join("kvantum.kvconfig").to_str().unwrap_or_default(), "General", "theme", Some(&kv));
        "kvantum"
    } else {
        "Breeze"
    };
    kwrite("kdeglobals", "KDE", "widgetStyle", Some(widget));
    // KGlobalSettings::StyleChanged → running KDE apps switch style
    conn.emit_signal(None::<()>, "/KGlobalSettings", "org.kde.KGlobalSettings", "notifyChange", &(2i32, 0i32))
        .await?;

    // 5. KWin blur strength (shared by apps, the shell and Plasma popups)
    let strength = t.blur.then(|| t.blur_strength.unwrap_or(12).to_string());
    kwrite("kwinrc", "Effect-blur", "BlurStrength", strength.as_deref());
    kwin(&conn, "/Effects", "org.kde.kwin.Effects", "reconfigureEffect", &("blur",)).await;

    // 6. kitty
    kitty_theme(t)?;

    // 7. shell (Appearance.qml watches this file)
    let json = serde_json::json!({ "id": t.id, "blur": t.blur, "dark": t.dark });
    write_atomic(&state.join("theme.json"), &format!("{json}\n"))?;
    Ok(())
}

pub async fn run(args: &[String]) -> Result<()> {
    let (file, args) = match args {
        [flag, f, rest @ ..] if flag == "--themes" => (PathBuf::from(f), rest),
        _ => (shell_dir().join("config/themes.json"), args),
    };
    let themes = load(&file)?;
    match args {
        [cmd, id] if cmd == "apply" => {
            let t = themes.iter().find(|t| &t.id == id).with_context(|| format!("unknown theme {id}"))?;
            apply(t).await
        }
        // Write the generated files into DIR without touching the desktop (parity tests, previews).
        [cmd, id, dir] if cmd == "render" => {
            let t = themes.iter().find(|t| &t.id == id).with_context(|| format!("unknown theme {id}"))?;
            let dir = Path::new(dir);
            std::fs::create_dir_all(dir)?;
            std::fs::write(dir.join(format!("{}.colors", scheme_name(t))), colour_scheme(t))?;
            std::fs::write(dir.join("kitty-theme.conf"), kitty_conf(t))?;
            let base = if t.dark { "KvFlat" } else { "KvFlatLight" };
            std::fs::write(dir.join(format!("KShell{}.kvconfig", camel(&t.id))), kvantum_conf(t, base))?;
            Ok(())
        }
        [cmd] if cmd == "current" => {
            let id = std::fs::read_to_string(state_dir().join("theme.json"))
                .ok()
                .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok())
                .and_then(|v| v["id"].as_str().map(String::from))
                .unwrap_or_else(|| "slate".into());
            println!("{id}");
            Ok(())
        }
        [cmd] if cmd == "list" => {
            for t in &themes {
                println!("{}", t.id);
            }
            Ok(())
        }
        _ => bail!("usage: kshelld theme [--themes FILE] apply <id> | current | list"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn camel_case_ids() {
        assert_eq!(camel("blur-dark"), "BlurDark");
        assert_eq!(camel("slate"), "Slate");
    }
}
