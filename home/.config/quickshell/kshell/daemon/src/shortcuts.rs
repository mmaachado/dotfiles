//! Swap global shortcuts between Plasma's defaults and KShell's.
//!
//!     kshell   Meta, Meta+Space and Alt+F1 → KShell launcher (Alt+F1 is what Toshy
//!              sends for Cmd+Space), Meta+W → wallpaper picker, KWin Overview → Meta+O,
//!              Meta+V → KShell clipboard (from Klipper), Print → region screenshot
//!              (from Spectacle's launcher), Meta+Shift+3/4/5 → screenshots and the
//!              capture toolbar
//!     plasma   restore Plasma's Meta, Meta+W, Meta+V and Print bindings

use anyhow::{Result, bail};
use zbus::Connection;

const META: i32 = 0x0100_0022; // Qt::Key_Meta (modifier-only shortcut)
const META_SPACE: i32 = 0x1000_0020; // Qt::META | Qt::Key_Space
const ALT_F1: i32 = 0x0800_0000 | 0x0100_0030;
const META_W: i32 = 0x1000_0000 | 0x57;
const META_O: i32 = 0x1000_0000 | 0x4F;
const META_V: i32 = 0x1000_0000 | 0x56;
const PRINT: i32 = 0x0100_0009; // Qt::Key_Print
const META_SHIFT_S: i32 = 0x1000_0000 | 0x0200_0000 | 0x53;

/// Meta+Shift+<digit>, spelled every way KDE may see it: by the shifted
/// symbol (`Meta+#`, which is how KGlobalAccel records Shift+digit on US
/// layouts), with Shift kept (`Meta+Shift+#`), and by the digit itself.
const fn meta_shift_digit(digit: i32, symbol: i32) -> [i32; 3] {
    const META_MOD: i32 = 0x1000_0000;
    const SHIFT_MOD: i32 = 0x0200_0000;
    [
        META_MOD | symbol,
        META_MOD | SHIFT_MOD | symbol,
        META_MOD | SHIFT_MOD | digit,
    ]
}
const META_SHIFT_3: [i32; 3] = meta_shift_digit(0x33, 0x23); // #
const META_SHIFT_4: [i32; 3] = meta_shift_digit(0x34, 0x24); // $
const META_SHIFT_5: [i32; 3] = meta_shift_digit(0x35, 0x25); // %

const PLASMA: [&str; 4] = ["plasmashell", "activate application launcher", "", ""];
const KSHELL: [&str; 4] = ["kwin", "KShell Launcher", "", ""];
const OVERVIEW: [&str; 4] = ["kwin", "Overview", "", ""];
const WALLPAPERS: [&str; 4] = ["kwin", "KShell Wallpapers", "", ""];
const KLIPPER: [&str; 4] = ["plasmashell", "show-on-mouse-pos", "", ""];
const CLIPBOARD: [&str; 4] = ["kwin", "KShell Clipboard", "", ""];
const SPECTACLE: [&str; 4] = ["org.kde.spectacle.desktop", "_launch", "", ""];
const SHOT: [&str; 4] = ["kwin", "KShell Screenshot", "", ""];
const SHOT_REGION: [&str; 4] = ["kwin", "KShell Screenshot Region", "", ""];
const CAPTURE_BAR: [&str; 4] = ["kwin", "KShell Capture Toolbar", "", ""];

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
            set_keys(&conn, KLIPPER, &[]).await?; // free Meta+V first
            set_keys(&conn, CLIPBOARD, &[META_V]).await?;
            set_keys(&conn, SPECTACLE, &[META_SHIFT_S]).await?; // free Print first
            set_keys(&conn, SHOT, &META_SHIFT_3).await?;
            let mut region = vec![PRINT];
            region.extend(META_SHIFT_4);
            set_keys(&conn, SHOT_REGION, &region).await?;
            set_keys(&conn, CAPTURE_BAR, &META_SHIFT_5).await?;
        }
        [p] if p == "plasma" => {
            set_keys(&conn, KSHELL, &[META_SPACE]).await?;
            set_keys(&conn, PLASMA, &[META, ALT_F1]).await?;
            set_keys(&conn, WALLPAPERS, &[]).await?;
            set_keys(&conn, OVERVIEW, &[META_W]).await?;
            set_keys(&conn, CLIPBOARD, &[]).await?;
            set_keys(&conn, KLIPPER, &[META_V]).await?;
            set_keys(&conn, SHOT, &[]).await?;
            set_keys(&conn, SHOT_REGION, &[]).await?;
            set_keys(&conn, CAPTURE_BAR, &[]).await?;
            set_keys(&conn, SPECTACLE, &[PRINT, META_SHIFT_S]).await?;
        }
        _ => bail!("usage: kshelld shortcuts kshell|plasma"),
    }
    Ok(())
}
