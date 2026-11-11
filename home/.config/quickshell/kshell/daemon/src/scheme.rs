//! Material 3 colour schemes from a wallpaper or a seed colour.
//!
//!     scheme (--wallpaper IMG | --seed #RRGGBB) [--variant V] [--light] [--contrast C] [--out F]
//!
//! Writes JSON (default ~/.local/state/kshell/scheme.json) with the source
//! colour and every M3 role in camelCase (`primary`, `onSurfaceVariant`,
//! `surfaceContainerHigh`, …) as #rrggbb. config/Appearance.qml watches it.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};
use image::imageops::FilterType;
use material_colors::color::Rgb;
use material_colors::dynamic_color::{DynamicScheme, Variant};
use material_colors::image::extract_color;
use material_colors::scheme::Scheme;
use serde_json::{Map, Value, json};

use crate::paths::{state_dir, write_atomic};

pub const VARIANTS: [(&str, Variant); 9] = [
    ("tonal-spot", Variant::TonalSpot),
    ("expressive", Variant::Expressive),
    ("vibrant", Variant::Vibrant),
    ("fidelity", Variant::Fidelity),
    ("content", Variant::Content),
    ("rainbow", Variant::Rainbow),
    ("fruit-salad", Variant::FruitSalad),
    ("neutral", Variant::Neutral),
    ("monochrome", Variant::Monochrome),
];

pub fn parse_hex(s: &str) -> Result<Rgb> {
    let h = s.trim_start_matches('#');
    if h.len() != 6 {
        bail!("expected #RRGGBB, got {s}");
    }
    Ok(Rgb::from_u32(u32::from_str_radix(h, 16).with_context(|| format!("bad colour {s}"))?))
}

fn hex(c: Rgb) -> String {
    format!("#{:06x}", c.as_u32() & 0xff_ffff)
}

/// The dominant "theme-worthy" colour of an image (quantize + score, as matugen
/// and Android do), from a ≤128 px downscale so it stays fast on 4K wallpapers.
pub fn wallpaper_seed(path: &Path) -> Result<Rgb> {
    let img = image::ImageReader::open(path)
        .with_context(|| format!("opening {}", path.display()))?
        .with_guessed_format()?
        .decode()
        .with_context(|| format!("decoding {}", path.display()))?
        .resize(128, 128, FilterType::Triangle)
        .into_rgb8();
    let pixels: Vec<Rgb> = img.pixels().map(|p| Rgb::new(p[0], p[1], p[2])).collect();
    Ok(extract_color(&pixels))
}

fn camel(snake: &str) -> String {
    let mut out = String::with_capacity(snake.len());
    let mut up = false;
    for ch in snake.chars() {
        if ch == '_' {
            up = true;
        } else if up {
            out.extend(ch.to_uppercase());
            up = false;
        } else {
            out.push(ch);
        }
    }
    out
}

pub fn build(seed: Rgb, variant: Variant, dark: bool, contrast: f64) -> Scheme {
    DynamicScheme::by_variant(seed, &variant, dark, Some(contrast)).into()
}

pub fn to_json(seed: Rgb, variant: &str, dark: bool, scheme: Scheme, wallpaper: Option<&Path>) -> Value {
    let colors: Map<String, Value> = scheme.into_iter().map(|(k, c)| (camel(k), Value::String(hex(c)))).collect();
    json!({
        "source": hex(seed),
        "variant": variant,
        "dark": dark,
        "wallpaper": wallpaper.map(|p| p.display().to_string()),
        "colors": colors,
    })
}

pub fn main(args: &[String]) -> Result<()> {
    let mut wallpaper: Option<PathBuf> = None;
    let mut seed: Option<Rgb> = None;
    let mut variant = "tonal-spot".to_string();
    let mut dark = true;
    let mut contrast = 0.0;
    let mut out = state_dir().join("scheme.json");

    let mut it = args.iter();
    while let Some(a) = it.next() {
        let mut val = || it.next().with_context(|| format!("{a} needs a value"));
        match a.as_str() {
            "--wallpaper" => wallpaper = Some(val()?.into()),
            "--seed" => seed = Some(parse_hex(val()?)?),
            "--variant" => variant = val()?.clone(),
            "--light" => dark = false,
            "--dark" => dark = true,
            "--contrast" => contrast = val()?.parse().context("--contrast takes a number in -1..1")?,
            "--out" => out = val()?.into(),
            "-" => out = PathBuf::from("-"),
            _ => bail!("unknown argument {a}"),
        }
    }
    let v = VARIANTS
        .iter()
        .find(|(n, _)| *n == variant)
        .map(|(_, v)| *v)
        .with_context(|| format!("unknown variant {variant}; one of {:?}", VARIANTS.map(|(n, _)| n)))?;
    let seed = match (seed, &wallpaper) {
        (Some(s), _) => s,
        (None, Some(w)) => wallpaper_seed(w)?,
        (None, None) => bail!("need --wallpaper IMG or --seed #RRGGBB"),
    };

    let json = to_json(seed, &variant, dark, build(seed, v, dark, contrast), wallpaper.as_deref());
    let text = serde_json::to_string_pretty(&json)? + "\n";
    if out == Path::new("-") {
        print!("{text}");
    } else {
        write_atomic(&out, &text)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Reference values from Google's material-color-utilities 0.4.0 (TypeScript)
    /// for seed #4285f4: primary, surface, onSurfaceVariant, surfaceContainerHigh.
    #[test]
    fn matches_material_color_utilities() {
        let seed = parse_hex("#4285f4").unwrap();
        let cases = [
            (Variant::TonalSpot, true, ["#adc6ff", "#111318", "#c4c6d0", "#282a2f"]),
            (Variant::TonalSpot, false, ["#445e91", "#f9f9ff", "#44474f", "#e8e7ee"]),
            (Variant::Expressive, true, ["#9bd595", "#12131a", "#c6c5d6", "#292931"]),
            (Variant::Expressive, false, ["#356a35", "#fbf8ff", "#454654", "#e9e7f2"]),
        ];
        for (variant, dark, want) in cases {
            let s = build(seed, variant, dark, 0.0);
            let got = [s.primary, s.surface, s.on_surface_variant, s.surface_container_high].map(hex);
            assert_eq!(got, want, "{variant:?} dark={dark}");
        }
    }

    #[test]
    fn json_roles_are_camel_case() {
        let seed = parse_hex("#6750a4").unwrap();
        let j = to_json(seed, "tonal-spot", true, build(seed, Variant::TonalSpot, true, 0.0), None);
        assert!(j["colors"]["onSurfaceVariant"].is_string());
        assert!(j["colors"]["surfaceContainerHighest"].is_string());
        assert_eq!(j["source"], "#6750a4");
    }
}
