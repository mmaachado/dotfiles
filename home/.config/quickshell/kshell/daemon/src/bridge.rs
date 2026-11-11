//! Bridge between KWin and KShell.
//!
//! KWin on Wayland exposes no window list to third-party shells, so this owns
//! org.kshell.Bridge on the session bus and loads bridge.js into KWin, which
//! calls back with state. Everything is relayed to Quickshell over stdout:
//!     state <json>      window/desktop state
//!     ipc <target> <fn> shortcut pressed in KWin
//! Commands from Quickshell arrive on stdin:
//!     activate|toggle|close <window id>
//!     desktop <desktop id>

use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{Context, Result, bail};
use futures_util::StreamExt;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::signal::unix::{SignalKind, signal};
use tokio::sync::mpsc;
use tokio::time::{Instant, sleep_until};
use zbus::fdo::{DBusProxy, RequestNameFlags};
use zbus::Variant;
use zbus::{Connection, interface};

const NAME: &str = "org.kshell.Bridge";
const PATH: &str = "/org/kshell/Bridge";
/// Bursts of updates (e.g. terminals animating their title) are coalesced.
const COALESCE: Duration = Duration::from_millis(60);

enum Event {
    Update(String),
    Line(String),
}

struct Bridge(mpsc::UnboundedSender<Event>);

#[interface(name = "org.kshell.Bridge")]
impl Bridge {
    fn update(&self, state: String) {
        let _ = self.0.send(Event::Update(state));
    }
    fn ipc(&self, cmd: String) {
        let _ = self.0.send(Event::Line(format!("ipc {cmd}")));
    }
    fn toggle_launcher(&self) {
        let _ = self.0.send(Event::Line("ipc launcher toggle".into()));
    }
}

struct Kwin {
    conn: Connection,
    runtime: PathBuf,
    // Per-process plugin names: on a Quickshell reload the old and new bridge
    // overlap, and a shared name lets the old one's cleanup unload the new script.
    plugin: String,
    action_plugin: String,
}

impl Kwin {
    async fn call<B>(&self, path: &str, iface: &str, method: &str, body: &B) -> zbus::Result<zbus::Message>
    where
        B: serde::Serialize + zbus::zvariant::DynamicType,
    {
        self.conn
            .call_method(Some("org.kde.KWin"), path, Some(iface), method, body)
            .await
    }

    async fn unload(&self, plugin: &str) -> zbus::Result<()> {
        self.call("/Scripting", "org.kde.kwin.Scripting", "unloadScript", &(plugin,))
            .await
            .map(drop)
    }

    async fn run_script(&self, path: &Path, plugin: &str) -> Result<()> {
        let _ = self.unload(plugin).await;
        let file = path.to_str().context("non-UTF-8 script path")?;
        let reply = self
            .call("/Scripting", "org.kde.kwin.Scripting", "loadScript", &(file, plugin))
            .await?;
        let id: i32 = reply.body().deserialize()?;
        self.call(&format!("/Scripting/Script{id}"), "org.kde.kwin.Script", "run", &())
            .await?;
        Ok(())
    }

    async fn action(&self, kind: &str, target: &str) -> Result<()> {
        if kind == "desktop" {
            self.call(
                "/VirtualDesktopManager",
                "org.freedesktop.DBus.Properties",
                "Set",
                &("org.kde.KWin.VirtualDesktopManager", "current", Variant::from(target)),
            )
            .await?;
            return Ok(());
        }
        let body = match kind {
            "activate" => "w.minimized = false; workspace.activeWindow = w;",
            "toggle" => {
                "if (workspace.activeWindow === w && !w.minimized) w.minimized = true; \
                 else { w.minimized = false; workspace.activeWindow = w; }"
            }
            "close" => "w.closeWindow();",
            _ => return Ok(()),
        };
        // KWin has no D-Bus call to act on a window by id, so run a one-shot script.
        let src = format!(
            "for (const w of workspace.windowList()) if (w.internalId.toString() === {}) {{ {body} break; }}",
            serde_json::to_string(target)?
        );
        let path = self.runtime.join("action.js");
        std::fs::write(&path, src)?;
        self.run_script(&path, &self.action_plugin).await
    }

    /// Unload the scripts of a previous bridge that died without cleaning up.
    async fn cleanup_stale(&self) {
        let Ok(old) = std::fs::read_to_string(self.runtime.join("plugin")) else {
            return;
        };
        let old = old.trim();
        let pid = old.rsplit('-').next().unwrap_or_default();
        if !old.is_empty() && !Path::new(&format!("/proc/{pid}")).exists() {
            let _ = self.unload(old).await;
            let _ = self.unload(&old.replace("bridge", "action")).await;
        }
    }
}

/// Write a stdout line; false once Quickshell has gone away.
fn emit(line: &str) -> bool {
    let mut out = std::io::stdout().lock();
    writeln!(out, "{line}").and_then(|()| out.flush()).is_ok()
}

pub async fn run(args: &[String]) -> Result<()> {
    let [script] = args else { bail!("usage: kshelld bridge <bridge.js>") };
    let script = std::fs::canonicalize(script).with_context(|| format!("no script at {script}"))?;

    let runtime = std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| "/tmp".into())
        .join("kshell");
    std::fs::create_dir_all(&runtime)?;

    let (tx, mut rx) = mpsc::unbounded_channel();
    let conn = Connection::session().await?;
    conn.object_server().at(PATH, Bridge(tx)).await?;

    let dbus = DBusProxy::new(&conn).await?;
    let mut name_lost = dbus.receive_name_lost().await?;
    conn.request_name_with_flags(NAME, RequestNameFlags::REPLACE_EXISTING | RequestNameFlags::ALLOW_REPLACEMENT)
        .await?;

    let pid = std::process::id();
    let kwin = Kwin {
        conn: conn.clone(),
        runtime: runtime.clone(),
        plugin: format!("kshell-bridge-{pid}"),
        action_plugin: format!("kshell-action-{pid}"),
    };
    kwin.cleanup_stale().await;
    kwin.run_script(&script, &kwin.plugin).await?;
    std::fs::write(runtime.join("plugin"), &kwin.plugin)?;

    let mut stdin = BufReader::new(tokio::io::stdin()).lines();
    let (mut term, mut int, mut hup) =
        (signal(SignalKind::terminate())?, signal(SignalKind::interrupt())?, signal(SignalKind::hangup())?);
    let mut pending: Option<String> = None;
    let mut deadline = Instant::now();

    loop {
        tokio::select! {
            Some(ev) = rx.recv() => match ev {
                Event::Update(state) => {
                    if pending.is_none() {
                        deadline = Instant::now() + COALESCE;
                    }
                    pending = Some(state);
                }
                Event::Line(line) => if !emit(&line) { break },
            },
            () = sleep_until(deadline), if pending.is_some() => {
                if !emit(&format!("state {}", pending.take().unwrap_or_default())) {
                    break;
                }
            }
            line = stdin.next_line() => match line {
                Ok(Some(line)) => {
                    if let Some((kind, target)) = line.trim().split_once(' ')
                        && let Err(e) = kwin.action(kind, target).await
                    {
                        eprintln!("kshell-bridge: {e:#}");
                    }
                }
                _ => break, // stdin closed: Quickshell exited
            },
            Some(lost) = name_lost.next() => {
                if lost.args().is_ok_and(|a| a.name() == NAME) {
                    break; // a newer bridge replaced us
                }
            }
            _ = term.recv() => break,
            _ = int.recv() => break,
            _ = hup.recv() => break,
        }
    }

    for p in [&kwin.plugin, &kwin.action_plugin] {
        let _ = kwin.unload(p).await;
    }
    Ok(())
}
