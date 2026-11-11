//! Swap global shortcuts between Plasma's defaults and KShell's.
//!
//!     kshell   Meta, Meta+Space and Alt+F1 → KShell launcher (Alt+F1 is what Toshy
//!              sends for Cmd+Space), Meta+W → wallpaper picker, KWin Overview → Meta+O
//!     plasma   restore Plasma's Meta and Meta+W bindings

use anyhow::{Result, bail};
use zbus::Connection;

const META: i32 = 0x0100_0022; // Qt::Key_Meta (modifier-only shortcut)
const META_SPACE: i32 = 0x1000_0020; // Qt::META | Qt::Key_Space
const ALT_F1: i32 = 0x0800_0000 | 0x0100_0030;
const META_W: i32 = 0x1000_0000 | 0x57;
const META_O: i32 = 0x1000_0000 | 0x4F;

const PLASMA: [&str; 4] = ["plasmashell", "activate application launcher", "", ""];
const KSHELL: [&str; 4] = ["kwin", "KShell Launcher", "", ""];
const OVERVIEW: [&str; 4] = ["kwin", "Overview", "", ""];
const WALLPAPERS: [&str; 4] = ["kwin", "KShell Wallpapers", "", ""];

async fn set_keys(conn: &Connection, action: [&str; 4], keys: &[i32]) -> Result<()> {
    // a(ai): each shortcut is a struct holding four key combinations.
    let seqs: Vec<(Vec<i32>,)> = keys.iter().map(|&k| (vec![k, 0, 0, 0],)).collect();
    conn.call_method(
        Some("org.kde.kglobalaccel"),
        "/kglobalaccel",
        Some("org.kde.KGlobalAccel"),
        "setForeignShortcutKeys",
        &(action.to_vec(), seqs),
    )
    .await?;
    Ok(())
}

pub async fn run(args: &[String]) -> Result<()> {
    let conn = Connection::session().await?;
    match args {
        [p] if p == "kshell" => {
            set_keys(&conn, PLASMA, &[]).await?;
            set_keys(&conn, KSHELL, &[META, META_SPACE, ALT_F1]).await?;
            set_keys(&conn, OVERVIEW, &[META_O]).await?; // free Meta+W first
            set_keys(&conn, WALLPAPERS, &[META_W]).await?;
        }
        [p] if p == "plasma" => {
            set_keys(&conn, KSHELL, &[META_SPACE]).await?;
            set_keys(&conn, PLASMA, &[META, ALT_F1]).await?;
            set_keys(&conn, WALLPAPERS, &[]).await?;
            set_keys(&conn, OVERVIEW, &[META_W]).await?;
        }
        _ => bail!("usage: kshelld shortcuts kshell|plasma"),
    }
    Ok(())
}
