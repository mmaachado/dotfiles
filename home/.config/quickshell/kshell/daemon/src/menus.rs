//! VSCode-style context menus for apps, in each toolkit's own theming:
//! a Kvantum theme for Qt/KDE apps and Plasma, gtk.css for GTK 3 and 4, and
//! userChrome.css for Firefox.
//!
//! The look: a rounded panel with a thin border, text rows without icons,
//! the accent behind the row under the pointer, full-width separators.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use anyhow::Result;

use crate::theme::{Palette, Rgb, hexc};

const WHITE: Rgb = [255, 255, 255];

/// Panel corner radius and the gap between the panel's edge and its rows.
pub const MENU_RADIUS: u32 = 6;
/// Corner radius of the highlighted row.
pub const ITEM_RADIUS: u32 = 4;

/// `a` moved towards `b` by `t` (0..1).
pub fn mix(a: Rgb, b: Rgb, t: f32) -> Rgb {
    let m = |x: u8, y: u8| (f32::from(x) + (f32::from(y) - f32::from(x)) * t).round() as u8;
    [m(a[0], b[0]), m(a[1], b[1]), m(a[2], b[2])]
}

/// Menu colours, from a theme's palette.
pub struct Colours {
    pub bg: Rgb,
    pub border: Rgb,
    pub text: Rgb,
    pub shortcut: Rgb,
    pub disabled: Rgb,
    pub hover: Rgb,
    pub on_hover: Rgb,
}

impl Colours {
    pub fn new(p: &Palette, dark: bool) -> Self {
        // A touch lighter than the content area, as VSCode's menus are.
        let bg = if dark {
            mix(p.view, p.text, 0.04)
        } else {
            mix(p.view, WHITE, 0.6)
        };
        Self {
            bg,
            border: mix(bg, p.text, if dark { 0.16 } else { 0.14 }),
            text: p.text,
            shortcut: mix(bg, p.text, 0.6),
            disabled: mix(bg, p.text, 0.4),
            hover: p.accent,
            on_hover: p.on_accent(),
        }
    }
}

// ── Kvantum ──────────────────────────────────────────────────────────────────

/// Elements of the base theme's SVG that the generated ones replace.
const REPLACED: [&str; 5] = [
    "menu-normal",
    "menuitem-focused",
    "menuitem-pressed",
    "menuitem-toggled",
    "menuitem-separator",
];

/// The base theme's SVG with its menu elements swapped for ours. Kvantum looks
/// elements up by id, so the old ones are renamed out of the way.
pub fn kvantum_svg(base: &str, c: &Colours) -> String {
    let mut svg = base.to_owned();
    for id in REPLACED {
        svg = svg.replace(&format!("id=\"{id}"), &format!("id=\"kvbase-{id}"));
    }
    let ours = kvantum_elements(c);
    match svg.rfind("</svg>") {
        Some(end) => svg.insert_str(end, &ours),
        None => svg.push_str(&ours),
    }
    svg
}

fn kvantum_elements(c: &Colours) -> String {
    let mut s = String::from("\n<!-- KShell: VSCode-style menus -->\n");
    s += &nine_slice("menu-normal", c.bg, Some(c.border), MENU_RADIUS);
    for state in ["focused", "pressed", "toggled"] {
        s += &nine_slice(&format!("menuitem-{state}"), c.hover, None, ITEM_RADIUS);
    }
    // A 1px line across the middle; the clear rect sets the element's height.
    let _ = writeln!(
        s,
        r#"<g id="menuitem-separator"><rect width="10" height="9" fill-opacity="0"/><rect y="4" width="10" height="1" fill="{}"/></g>"#,
        hexc(c.border)
    );
    s
}

/// A Kvantum frame: interior `id`, edges `id-top`… and rounded corners
/// `id-topleft`…, each `r` px thick, with an optional 1px border.
fn nine_slice(id: &str, fill: Rgb, border: Option<Rgb>, r: u32) -> String {
    let (f, rb) = (hexc(fill), f64::from(r) - 0.5);
    let line = |x: u32, y: u32, w: u32, h: u32| {
        border.map_or(String::new(), |b| {
            format!(
                r#"<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{}"/>"#,
                hexc(b)
            )
        })
    };
    let arc = |d: String| {
        border.map_or(String::new(), |b| {
            format!(
                r#"<path d="{d}" fill="none" stroke="{}" stroke-width="1"/>"#,
                hexc(b)
            )
        })
    };
    let mut s = String::new();
    let _ = writeln!(s, r#"<rect id="{id}" width="10" height="10" fill="{f}"/>"#);
    // edges: fill, then the border along the outer side
    for (side, w, h, border_line) in [
        ("top", 1, r, line(0, 0, 1, 1)),
        ("bottom", 1, r, line(0, r - 1, 1, 1)),
        ("left", r, 1, line(0, 0, 1, 1)),
        ("right", r, 1, line(r - 1, 0, 1, 1)),
    ] {
        let _ = writeln!(
            s,
            r#"<g id="{id}-{side}"><rect width="{w}" height="{h}" fill="{f}"/>{border_line}</g>"#
        );
    }
    // corners: a quarter disc around the panel's inner corner, then its arc
    for (corner, disc, edge) in [
        (
            "topleft",
            format!("M {r},{r} L 0,{r} A {r},{r} 0 0 1 {r},0 Z"),
            format!("M 0.5,{r} A {rb},{rb} 0 0 1 {r},0.5"),
        ),
        (
            "topright",
            format!("M 0,{r} L 0,0 A {r},{r} 0 0 1 {r},{r} Z"),
            format!("M 0,0.5 A {rb},{rb} 0 0 1 {rb},{r}"),
        ),
        (
            "bottomright",
            format!("M 0,0 L {r},0 A {r},{r} 0 0 1 0,{r} Z"),
            format!("M {rb},0 A {rb},{rb} 0 0 1 0,{rb}"),
        ),
        (
            "bottomleft",
            format!("M {r},0 L {r},{r} A {r},{r} 0 0 1 0,0 Z"),
            format!("M {r},{rb} A {rb},{rb} 0 0 1 0.5,0"),
        ),
    ] {
        let _ = writeln!(
            s,
            r#"<g id="{id}-{corner}"><path d="{disc}" fill="{f}"/>{}</g>"#,
            arc(edge)
        );
    }
    s
}

/// Settings layered over the base theme's kvconfig for the menus.
pub fn kvantum_overrides(c: &Colours) -> Vec<(&'static str, &'static str, String)> {
    let (m, i) = (MENU_RADIUS.to_string(), ITEM_RADIUS.to_string());
    let mut out = vec![
        ("%General", "menu_separator_height", "9".into()),
        ("%General", "spread_menuitems", "false".into()),
        ("%General", "composite", "true".into()),
        ("%General", "submenu_overlap", "0".into()),
        // With a shadow Kvantum draws the menu's edge from the shadow elements,
        // leaving out the rounded, bordered frame below.
        ("%General", "menu_shadow_depth", "0".into()),
        ("Hacks", "iconless_menu", "true".into()),
    ];
    for k in ["frame.top", "frame.bottom", "frame.left", "frame.right"] {
        out.push(("Menu", k, m.clone()));
        out.push(("MenuItem", k, i.clone()));
    }
    out.extend([
        ("Menu", "frame.element", "menu".into()),
        ("Menu", "interior.element", "menu".into()),
        ("Menu", "frame", "true".into()),
        ("Menu", "interior", "true".into()),
        ("MenuItem", "frame", "true".into()),
        ("MenuItem", "interior", "true".into()),
        ("MenuItem", "frame.element", "menuitem".into()),
        ("MenuItem", "interior.element", "menuitem".into()),
        ("MenuItem", "indicator.element", "menuitem".into()),
        // the menu's frame plus these put the text 20px in, as in VSCode
        ("MenuItem", "text.margin.left", "10".into()),
        ("MenuItem", "text.margin.right", "10".into()),
        ("MenuItem", "text.margin.top", "3".into()),
        ("MenuItem", "text.margin.bottom", "3".into()),
        ("MenuItem", "text.normal.color", hexc(c.text)),
        ("MenuItem", "text.focus.color", hexc(c.on_hover)),
        ("MenuItem", "text.press.color", hexc(c.on_hover)),
        ("MenuItem", "text.toggle.color", hexc(c.on_hover)),
    ]);
    out
}

/// A kvconfig (INI) file, kept in order so the result diffs cleanly.
#[derive(Default)]
pub struct Ini {
    sections: Vec<(String, Vec<(String, String)>)>,
}

impl Ini {
    pub fn parse(text: &str) -> Self {
        let mut ini = Self::default();
        for line in text.lines() {
            let line = line.trim();
            if let Some(name) = line.strip_prefix('[').and_then(|l| l.strip_suffix(']')) {
                ini.sections.push((name.to_owned(), Vec::new()));
            } else if let Some((k, v)) = line.split_once('=')
                && let Some((_, keys)) = ini.sections.last_mut()
            {
                keys.push((k.trim().to_owned(), v.trim().to_owned()));
            }
        }
        ini
    }

    pub fn set(&mut self, section: &str, key: &str, value: &str) {
        let i = match self.sections.iter().position(|(n, _)| n == section) {
            Some(i) => i,
            None => {
                self.sections.push((section.to_owned(), Vec::new()));
                self.sections.len() - 1
            }
        };
        let keys = &mut self.sections[i].1;
        match keys.iter_mut().find(|(k, _)| k == key) {
            Some(e) => e.1 = value.to_owned(),
            None => keys.push((key.to_owned(), value.to_owned())),
        }
    }
}

impl std::fmt::Display for Ini {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        for (i, (name, keys)) in self.sections.iter().enumerate() {
            if i > 0 {
                writeln!(f)?;
            }
            writeln!(f, "[{name}]")?;
            for (k, v) in keys {
                writeln!(f, "{k}={v}")?;
            }
        }
        Ok(())
    }
}

// ── GTK ──────────────────────────────────────────────────────────────────────

const GTK_HEADER: &str = "/* KShell: VSCode-style menus. Generated by kshelld for each theme; edits are overwritten. */\n";
const GTK_FILE: &str = "kshell-menus.css";

/// GTK 3: `menu` popups (context menus, menu bars' menus).
pub fn gtk3_css(c: &Colours) -> String {
    let v = vars(c);
    format!(
        "{GTK_HEADER}
menu, .menu, .context-menu {{
  background-color: {bg};
  border: 1px solid {border};
  border-radius: {mr}px;
  padding: 4px;
  box-shadow: none;
}}
.csd.popup decoration {{ border-radius: {mr}px; }}
menu menuitem {{
  min-height: 0;
  padding: 6px 16px;
  border-radius: {ir}px;
  border: none;
  box-shadow: none;
  color: {text};
  text-shadow: none;
}}
menu menuitem:hover {{ background-color: {hover}; color: {on_hover}; }}
menu menuitem:disabled {{ color: {disabled}; }}
menu menuitem accelerator {{ color: {shortcut}; margin-left: 40px; }}
menu menuitem:hover accelerator {{ color: alpha({on_hover}, 0.8); }}
menu menuitem arrow {{ min-width: 12px; }}
menu separator {{ margin: 4px 0; min-height: 1px; background-color: {border}; }}
",
        bg = v.bg,
        border = v.border,
        text = v.text,
        shortcut = v.shortcut,
        disabled = v.disabled,
        hover = v.hover,
        on_hover = v.on_hover,
        mr = MENU_RADIUS,
        ir = ITEM_RADIUS,
    )
}

/// GTK 4 (and libadwaita): menus are popovers of model buttons.
pub fn gtk4_css(c: &Colours) -> String {
    let v = vars(c);
    format!(
        "{GTK_HEADER}
popover.menu > contents {{
  background-color: {bg};
  border: 1px solid {border};
  border-radius: {mr}px;
  padding: 4px;
  box-shadow: none;
}}
popover.menu > arrow {{ background-color: {bg}; border-color: {border}; }}
popover.menu modelbutton {{
  min-height: 0;
  padding: 6px 16px;
  border-radius: {ir}px;
  border: none;
  box-shadow: none;
  color: {text};
}}
popover.menu modelbutton:hover, popover.menu modelbutton:selected {{ background-color: {hover}; color: {on_hover}; }}
popover.menu modelbutton:disabled {{ color: {disabled}; }}
popover.menu modelbutton accelerator {{ color: {shortcut}; margin-left: 40px; }}
popover.menu modelbutton:hover accelerator, popover.menu modelbutton:selected accelerator {{ color: alpha({on_hover}, 0.8); }}
popover.menu separator {{ margin: 4px 0; min-height: 1px; background-color: {border}; }}
",
        bg = v.bg,
        border = v.border,
        text = v.text,
        shortcut = v.shortcut,
        disabled = v.disabled,
        hover = v.hover,
        on_hover = v.on_hover,
        mr = MENU_RADIUS,
        ir = ITEM_RADIUS,
    )
}

struct Hex {
    bg: String,
    border: String,
    text: String,
    shortcut: String,
    disabled: String,
    hover: String,
    on_hover: String,
}

fn vars(c: &Colours) -> Hex {
    Hex {
        bg: hexc(c.bg),
        border: hexc(c.border),
        text: hexc(c.text),
        shortcut: hexc(c.shortcut),
        disabled: hexc(c.disabled),
        hover: hexc(c.hover),
        on_hover: hexc(c.on_hover),
    }
}

/// gtk.css with an import of `file` after its other imports (Plasma keeps
/// `@import 'colors.css';` there and leaves other lines alone).
pub fn with_import(gtk_css: &str, file: &str) -> String {
    with_line(gtk_css, &format!("@import '{file}';"))
}

/// A stylesheet with `import` added after its other @import lines (they have
/// to come before any rule), unless it's there already.
fn with_line(css: &str, import: &str) -> String {
    if css.lines().any(|l| l.trim() == import) {
        return css.to_owned();
    }
    let mut lines: Vec<&str> = css.lines().collect();
    let at = lines
        .iter()
        .rposition(|l| l.trim_start().starts_with("@import"))
        .map_or(0, |i| i + 1);
    lines.insert(at, import);
    lines.join("\n") + "\n"
}

/// Write the menu CSS into ~/.config/gtk-3.0 and gtk-4.0 and import it.
pub fn install_gtk(config: &Path, c: &Colours) -> Result<()> {
    for (dir, css) in [("gtk-3.0", gtk3_css(c)), ("gtk-4.0", gtk4_css(c))] {
        let dir = config.join(dir);
        std::fs::create_dir_all(&dir)?;
        std::fs::write(dir.join(GTK_FILE), css)?;
        let main = dir.join("gtk.css");
        let old = std::fs::read_to_string(&main).unwrap_or_default();
        let new = with_import(&old, GTK_FILE);
        if new != old {
            std::fs::write(&main, new)?;
        }
    }
    Ok(())
}

/// The generated GTK files, by name, for `kshelld theme render`.
pub fn gtk_files(c: &Colours) -> [(&'static str, String); 2] {
    [
        ("gtk-3.0-kshell-menus.css", gtk3_css(c)),
        ("gtk-4.0-kshell-menus.css", gtk4_css(c)),
    ]
}

// ── Firefox ──────────────────────────────────────────────────────────────────

const FIREFOX_FILE: &str = "kshell-menus.css";
const FIREFOX_PREF: &str =
    "user_pref(\"toolkit.legacyUserProfileCustomizations.stylesheets\", true);";

/// Firefox's menus (toolkit menu.css and popup.css), through the variables
/// they're drawn with.
pub fn firefox_css(c: &Colours) -> String {
    let v = vars(c);
    format!(
        "/* KShell: VSCode-style menus. Generated by kshelld for each theme; edits are overwritten. */
menupopup:not([type=\"arrow\"]) {{
  --panel-background-color: {bg} !important;
  --panel-text-color: {text} !important;
  --panel-border-color: {border} !important;
  --panel-separator-color: {border} !important;
  --panel-border-radius: {mr}px !important;
  --panel-padding: 4px !important;
  --panel-padding-block: 4px !important;
  --menuitem-border-radius: {ir}px !important;
  --menuitem-padding-block: 6px !important;
  --menuitem-padding-inline: 16px !important;
  --text-color-disabled: {disabled} !important;
}}
menupopup :is(menu, menuitem)[_moz-menuactive]:not([disabled]) {{
  background-color: {hover} !important;
  color: {on_hover} !important;
}}
menupopup :is(menu, menuitem)[_moz-menuactive][disabled] {{ background-color: transparent !important; }}
menupopup .menu-accel {{ color: {shortcut} !important; margin-inline-start: 40px !important; }}
menupopup [_moz-menuactive]:not([disabled]) .menu-accel {{ color: {on_hover} !important; opacity: 0.8; }}
menupopup > menuseparator {{ padding-block: 4px !important; margin-inline: -4px !important; }}
",
        bg = v.bg,
        border = v.border,
        text = v.text,
        shortcut = v.shortcut,
        disabled = v.disabled,
        hover = v.hover,
        on_hover = v.on_hover,
        mr = MENU_RADIUS,
        ir = ITEM_RADIUS,
    )
}

/// Profile folders listed in profiles.ini under each Firefox root.
pub fn firefox_profiles(home: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    for root in [".config/mozilla/firefox", ".mozilla/firefox"] {
        let root = home.join(root);
        let Ok(text) = std::fs::read_to_string(root.join("profiles.ini")) else {
            continue;
        };
        let ini = Ini::parse(&text);
        for (name, keys) in &ini.sections {
            let get = |k: &str| {
                keys.iter()
                    .find(|(key, _)| key == k)
                    .map(|(_, v)| v.as_str())
            };
            if !name.starts_with("Profile") {
                continue;
            }
            if let Some(path) = get("Path") {
                let dir = if get("IsRelative") == Some("0") {
                    PathBuf::from(path)
                } else {
                    root.join(path)
                };
                if dir.is_dir() {
                    out.push(dir);
                }
            }
        }
    }
    out
}

/// Write the menu CSS into every profile, import it from userChrome.css and
/// let Firefox load userChrome.css. Firefox reads it at startup.
pub fn install_firefox(home: &Path, c: &Colours) -> Result<()> {
    let css = firefox_css(c);
    for profile in firefox_profiles(home) {
        let chrome = profile.join("chrome");
        std::fs::create_dir_all(&chrome)?;
        std::fs::write(chrome.join(FIREFOX_FILE), &css)?;
        let user_chrome = chrome.join("userChrome.css");
        let old = std::fs::read_to_string(&user_chrome).unwrap_or_default();
        let new = with_line(&old, &format!("@import url(\"{FIREFOX_FILE}\");"));
        if new != old {
            std::fs::write(&user_chrome, new)?;
        }
        let user_js = profile.join("user.js");
        let old = std::fs::read_to_string(&user_js).unwrap_or_default();
        if !old.lines().any(|l| l.trim() == FIREFOX_PREF) {
            let sep = if old.is_empty() || old.ends_with('\n') {
                ""
            } else {
                "\n"
            };
            std::fs::write(&user_js, format!("{old}{sep}{FIREFOX_PREF}\n"))?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn colours() -> Colours {
        Colours {
            bg: [31, 31, 31],
            border: [69, 69, 69],
            text: [204, 204, 204],
            shortcut: [130, 130, 130],
            disabled: [100, 100, 100],
            hover: [0, 120, 212],
            on_hover: WHITE,
        }
    }

    #[test]
    fn mixes() {
        assert_eq!(mix([0, 0, 0], WHITE, 0.5), [128, 128, 128]);
        assert_eq!(mix([10, 20, 30], [10, 20, 30], 0.7), [10, 20, 30]);
    }

    #[test]
    fn svg_replaces_menu_elements_once() {
        let base = r#"<svg><rect id="menu-normal"/><g id="menu-normal-top"/><rect id="menuitem-pressed-left"/><rect id="menu-shadow-top"/></svg>"#;
        let svg = kvantum_svg(base, &colours());
        assert!(svg.contains(r#"id="kvbase-menu-normal""#));
        assert!(svg.contains(r#"id="kvbase-menu-normal-top""#));
        assert!(svg.contains(r#"id="kvbase-menuitem-pressed-left""#));
        // shadows are kept as they are
        assert!(svg.contains(r#"id="menu-shadow-top""#));
        for id in [
            "menu-normal",
            "menu-normal-topleft",
            "menuitem-focused-bottomright",
            "menuitem-separator",
        ] {
            assert_eq!(svg.matches(&format!("id=\"{id}\"")).count(), 1, "{id}");
        }
        assert!(svg.trim_end().ends_with("</svg>"));
    }

    #[test]
    fn ini_overrides_keep_order() {
        let mut ini = Ini::parse("[%General]\nauthor=x\ncomposite=false\n\n[Menu]\nframe.top=3\n");
        ini.set("%General", "composite", "true");
        ini.set("Menu", "frame.left", "6");
        ini.set("Hacks", "iconless_menu", "true");
        assert_eq!(
            ini.to_string(),
            "[%General]\nauthor=x\ncomposite=true\n\n[Menu]\nframe.top=3\nframe.left=6\n\n[Hacks]\niconless_menu=true\n"
        );
    }

    #[test]
    fn gtk_import_goes_after_plasmas() {
        assert_eq!(
            with_import("@import 'colors.css';", GTK_FILE),
            "@import 'colors.css';\n@import 'kshell-menus.css';\n"
        );
        assert_eq!(
            with_import(
                "@import 'colors.css';\n\nwindow { color: red; }\n",
                GTK_FILE
            ),
            "@import 'colors.css';\n@import 'kshell-menus.css';\n\nwindow { color: red; }\n"
        );
        assert_eq!(with_import("", GTK_FILE), "@import 'kshell-menus.css';\n");
        let once = with_import("@import 'colors.css';\n", GTK_FILE);
        assert_eq!(with_import(&once, GTK_FILE), once);
    }

    #[test]
    fn gtk_css_uses_the_colours() {
        let c = colours();
        for css in [gtk3_css(&c), gtk4_css(&c)] {
            assert!(css.contains("background-color: #1f1f1f;"));
            assert!(css.contains("background-color: #0078d4; color: #ffffff;"));
            assert_eq!(css.matches('{').count(), css.matches('}').count());
        }
    }

    #[test]
    fn firefox_profiles_from_ini() {
        let home = std::env::temp_dir().join(format!("kshelld-ff-{}", std::process::id()));
        let root = home.join(".config/mozilla/firefox");
        std::fs::create_dir_all(root.join("abc.default-release")).unwrap();
        std::fs::create_dir_all(root.join("gone")).unwrap();
        std::fs::write(
            root.join("profiles.ini"),
            "[General]\nVersion=2\n\n[Profile0]\nIsRelative=1\nPath=abc.default-release\n\n[Install1]\nDefault=abc.default-release\n\n[Profile1]\nIsRelative=1\nPath=missing\n",
        )
        .unwrap();
        assert_eq!(
            firefox_profiles(&home),
            vec![root.join("abc.default-release")]
        );

        let profile = root.join("abc.default-release");
        std::fs::create_dir_all(profile.join("chrome")).unwrap();
        std::fs::write(
            profile.join("chrome/userChrome.css"),
            "#nav-bar { color: red; }\n",
        )
        .unwrap();
        std::fs::write(profile.join("user.js"), "user_pref(\"a\", 1);").unwrap();
        for _ in 0..2 {
            install_firefox(&home, &colours()).unwrap();
        }
        let user_chrome = std::fs::read_to_string(profile.join("chrome/userChrome.css")).unwrap();
        assert_eq!(
            user_chrome,
            "@import url(\"kshell-menus.css\");\n#nav-bar { color: red; }\n"
        );
        let user_js = std::fs::read_to_string(profile.join("user.js")).unwrap();
        assert_eq!(user_js, format!("user_pref(\"a\", 1);\n{FIREFOX_PREF}\n"));
        assert!(profile.join("chrome/kshell-menus.css").is_file());
        std::fs::remove_dir_all(&home).unwrap();
    }
}
