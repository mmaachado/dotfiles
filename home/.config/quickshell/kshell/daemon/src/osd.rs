//! Plasma's OSD events, relayed so the shell can draw its own.
//!
//! plasmashell's osdService broadcasts osdProgress / osdText whenever it
//! shows an OSD (volume and brightness keys, mic mute, keyboard layout,
//! power profile, ...). Each one becomes a JSON line on stdout:
//!     {"kind":"progress","icon":"audio-volume-high","value":40,"max":100,"text":""}
//!     {"kind":"text","icon":"input-keyboard","text":"English (US)"}

use std::io::Write;

use anyhow::Result;
use futures_util::StreamExt;
use serde_json::json;
use zbus::message::Type;
use zbus::{Connection, MatchRule, MessageStream};

pub async fn run(_args: &[String]) -> Result<()> {
    let conn = Connection::session().await?;
    let rule = MatchRule::builder()
        .msg_type(Type::Signal)
        .interface("org.kde.osdService")
        .path("/org/kde/osdService")
        .build()?;
    let mut signals = MessageStream::for_match_rule(rule, &conn, None).await?;
    let mut stdin = tokio::io::BufReader::new(tokio::io::stdin());
    let mut sink = Vec::new();

    loop {
        tokio::select! {
            Some(Ok(msg)) = signals.next() => {
                let member = msg.header().member().map(|m| m.to_string()).unwrap_or_default();
                let body = msg.body();
                let line = match member.as_str() {
                    "osdProgress" => body.deserialize::<(String, i32, i32, String)>().ok().map(|(icon, value, max, text)| {
                        json!({ "kind": "progress", "icon": icon, "value": value, "max": max, "text": text })
                    }),
                    "osdText" => body.deserialize::<(String, String)>().ok().map(|(icon, text)| {
                        json!({ "kind": "text", "icon": icon, "text": text })
                    }),
                    _ => None,
                };
                if let Some(line) = line {
                    let mut out = std::io::stdout().lock();
                    if writeln!(out, "{line}").and_then(|()| out.flush()).is_err() {
                        break;
                    }
                }
            }
            // Exit with Quickshell: it closes our stdin.
            n = tokio::io::AsyncReadExt::read_buf(&mut stdin, &mut sink) => {
                if n.unwrap_or(0) == 0 {
                    break;
                }
                sink.clear();
            }
        }
    }
    Ok(())
}
