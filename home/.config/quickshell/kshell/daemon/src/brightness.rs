//! Screen brightness through PowerDevil (org.kde.ScreenBrightness), which
//! covers laptop panels and DDC/CI monitors alike.
//!
//! stdout:
//!     state <json>                      [{"name","label","brightness","max","internal"}], on start and on change
//!     changed <name> <fraction> <who>    a display's brightness changed; who = the setter's
//!                                       context ("kshell" for our own sets), else its name
//! stdin:
//!     set <name> <fraction>             set brightness (0..1) without Plasma's OSD

use std::io::Write;

use anyhow::Result;
use futures_util::StreamExt;
use serde_json::{Value, json};
use tokio::io::{AsyncBufReadExt, BufReader};
use zbus::message::Type;
use zbus::{Connection, MatchRule, MessageStream};

const SVC: &str = "org.kde.ScreenBrightness";
const ROOT: &str = "/org/kde/ScreenBrightness";
const IFACE: &str = "org.kde.ScreenBrightness";
const DISPLAY: &str = "org.kde.ScreenBrightness.Display";
/// SetBrightness flag: don't show Plasma's brightness OSD.
const SUPPRESS_INDICATOR: u32 = 0x1;

async fn prop(conn: &Connection, path: &str, iface: &str, name: &str) -> zbus::Result<zbus::OwnedVariant> {
    let reply = conn
        .call_method(Some(SVC), path, Some("org.freedesktop.DBus.Properties"), "Get", &(iface, name))
        .await?;
    let v: zbus::OwnedVariant = reply.body().deserialize()?;
    Ok(v)
}

async fn displays(conn: &Connection) -> Result<Vec<Value>> {
    let names: Vec<String> = prop(conn, ROOT, IFACE, "DisplaysDBusNames").await?.try_into()?;
    let mut out = Vec::new();
    for name in names {
        let path = format!("{ROOT}/{name}");
        let brightness: i32 = prop(conn, &path, DISPLAY, "Brightness").await?.try_into()?;
        let max: i32 = prop(conn, &path, DISPLAY, "MaxBrightness").await?.try_into()?;
        let label: String = prop(conn, &path, DISPLAY, "Label").await?.try_into()?;
        let internal: bool = prop(conn, &path, DISPLAY, "IsInternal").await?.try_into()?;
        out.push(json!({ "name": name, "label": label, "brightness": brightness, "max": max, "internal": internal }));
    }
    Ok(out)
}

fn emit(line: &str) -> bool {
    let mut out = std::io::stdout().lock();
    writeln!(out, "{line}").and_then(|()| out.flush()).is_ok()
}

async fn emit_state(conn: &Connection) -> bool {
    match displays(conn).await {
        Ok(d) => emit(&format!("state {}", Value::Array(d))),
        Err(e) => {
            eprintln!("kshelld brightness: {e:#}");
            emit("state []")
        }
    }
}

async fn set(conn: &Connection, name: &str, fraction: f64) -> Result<()> {
    let path = format!("{ROOT}/{name}");
    let max: i32 = prop(conn, &path, DISPLAY, "MaxBrightness").await?.try_into()?;
    let value = (fraction.clamp(0.0, 1.0) * f64::from(max)).round() as i32;
    conn.call_method(Some(SVC), path.as_str(), Some(DISPLAY), "SetBrightnessWithContext", &(value, SUPPRESS_INDICATOR, "kshell"))
        .await?;
    Ok(())
}

pub async fn run(_args: &[String]) -> Result<()> {
    let conn = Connection::session().await?;
    let rule = MatchRule::builder().msg_type(Type::Signal).interface(IFACE).path(ROOT).build()?;
    let mut signals = MessageStream::for_match_rule(rule, &conn, None).await?;
    let mut stdin = BufReader::new(tokio::io::stdin()).lines();

    if !emit_state(&conn).await {
        return Ok(());
    }
    loop {
        tokio::select! {
            Some(Ok(msg)) = signals.next() => {
                let member = msg.header().member().map(|m| m.to_string()).unwrap_or_default();
                if member == "BrightnessChanged"
                    && let Ok((name, value, source, ctx)) = msg.body().deserialize::<(String, i32, String, String)>()
                {
                    let max = prop(&conn, &format!("{ROOT}/{name}"), DISPLAY, "MaxBrightness").await
                        .ok().and_then(|v| i32::try_from(v).ok()).unwrap_or(0);
                    let fraction = if max > 0 { f64::from(value) / f64::from(max) } else { 0.0 };
                    let who = [ctx, source].into_iter().find(|s| !s.is_empty()).unwrap_or_else(|| "-".into());
                    let who = who.replace(char::is_whitespace, "_");
                    if !emit(&format!("changed {name} {fraction:.4} {who}")) {
                        break;
                    }
                }
                if !emit_state(&conn).await {
                    break;
                }
            }
            line = stdin.next_line() => match line {
                Ok(Some(line)) => {
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if let ["set", name, f] = parts[..]
                        && let Ok(f) = f.parse::<f64>()
                        && let Err(e) = set(&conn, name, f).await
                    {
                        eprintln!("kshelld brightness: {e:#}");
                    }
                }
                _ => break, // stdin closed: Quickshell exited
            },
        }
    }
    Ok(())
}
