//! kshelld: the native backend of KShell (Quickshell on KDE Plasma).
//!
//!     kshelld bridge <bridge.js>             KWin ↔ shell relay (stdin/stdout line protocol)
//!     kshelld theme [--themes F] apply <id>  apply a KShell theme desktop-wide
//!     kshelld theme [--themes F] current|list
//!     kshelld brightness                     screen brightness relay (stdin/stdout line protocol)
//!     kshelld shortcuts kshell|plasma        swap global shortcuts
//!     kshelld scheme (--wallpaper IMG | --seed #RRGGBB) [--variant V] [--light] [--out F]
//!                                            write a Material 3 colour scheme as JSON
mod bridge;
mod brightness;
mod paths;
mod scheme;
mod shortcuts;
mod theme;

use anyhow::{Result, bail};

const USAGE: &str = "usage: kshelld bridge <bridge.js> | brightness | theme [--themes F] apply <id>|current|list \
| shortcuts kshell|plasma | scheme (--wallpaper IMG | --seed HEX) [--variant V] [--light] [--out F]";

fn main() {
    if let Err(e) = run() {
        eprintln!("kshelld: {e:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let rest = args.get(1..).unwrap_or_default();
    match args.first().map(String::as_str) {
        Some("bridge") => block_on(bridge::run(rest)),
        Some("brightness") => block_on(brightness::run(rest)),
        Some("theme") => block_on(theme::run(rest)),
        Some("shortcuts") => block_on(shortcuts::run(rest)),
        Some("scheme") => scheme::main(rest),
        _ => bail!("{USAGE}"),
    }
}

fn block_on<F: Future<Output = Result<()>>>(f: F) -> Result<()> {
    tokio::runtime::Builder::new_current_thread().enable_all().build()?.block_on(f)
}
