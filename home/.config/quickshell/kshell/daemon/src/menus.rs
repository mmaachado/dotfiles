//! VSCode-style context menus for apps, in each toolkit's own theming:
//! a Kvantum theme for Qt/KDE apps and Plasma.
//!
//! The look: a rounded panel with a thin border, text rows without icons,
//! the accent behind the row under the pointer, full-width separators.

use std::fmt::Write as _;

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

#[cfg(test)]
mod tests {
    use super::*;

    fn colours() -> Colours {
        Colours {
            bg: [31, 31, 31],
            border: [69, 69, 69],
            text: [204, 204, 204],
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
}
