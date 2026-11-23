//! Clipboard history over ext-data-control (KWin, wlroots and others): no
//! Klipper or cliphist needed, and no window focus.
//!
//! stdout:
//!     history <json>     [{"id","kind","text","path","width","height","pinned","time"}],
//!                        newest first; on start and on change
//! stdin:
//!     copy <id>          put an entry back on the clipboard (and move it to the top)
//!     pin <id>           toggle pinned (pinned entries survive `clear` and the size cap)
//!     delete <id>
//!     clear
//!
//! Text and images. Images (PNG, JPEG, WebP; an offer with an image wins over
//! its text) are stored as PNG files named by content in
//! ~/.local/state/kshell/clipboard/, and served back as image/png. Copies
//! marked by password managers (x-kde-passwordManagerHint) are never stored.
//! History persists in ~/.local/state/kshell/clipboard.json.
//! When the clipboard empties (the app that copied quit), the newest entry is
//! put back, as Klipper does.

use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::io::{Read, Write};
use std::os::fd::AsFd;
use std::path::PathBuf;
use std::sync::mpsc;
use std::time::{SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use wayland_client::globals::{GlobalListContents, registry_queue_init};
use wayland_client::protocol::{wl_callback, wl_registry, wl_seat};
use wayland_client::{
    Connection, Dispatch, Proxy, QueueHandle, backend::ObjectId, event_created_child,
};
use wayland_protocols::ext::data_control::v1::client::{
    ext_data_control_device_v1::{self, ExtDataControlDeviceV1},
    ext_data_control_manager_v1::ExtDataControlManagerV1,
    ext_data_control_offer_v1::{self, ExtDataControlOfferV1},
    ext_data_control_source_v1::{self, ExtDataControlSourceV1},
};

use crate::paths::{state_dir, write_atomic};

const TEXT_MIMES: [&str; 5] = [
    "text/plain;charset=utf-8",
    "UTF8_STRING",
    "text/plain",
    "TEXT",
    "STRING",
];
const IMAGE_MIMES: [&str; 3] = ["image/png", "image/jpeg", "image/webp"];
const SECRET_HINT: &str = "x-kde-passwordManagerHint";
const MAX_ENTRIES: usize = 200;
const MAX_BYTES: usize = 256 * 1024;
/// Unpinned images kept, and the largest image read.
const MAX_IMAGES: usize = 30;
const MAX_IMAGE_BYTES: usize = 48 * 1024 * 1024;

fn text_kind() -> String {
    "text".into()
}

#[derive(Serialize, Deserialize, Clone)]
struct Entry {
    id: u64,
    // "text" or "image"; older history files have no kind (text).
    #[serde(default = "text_kind")]
    kind: String,
    #[serde(default)]
    text: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    path: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    width: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    height: Option<u32>,
    pinned: bool,
    time: u64,
}

impl Entry {
    fn is_image(&self) -> bool {
        self.kind == "image"
    }
}

/// What a selection read produced.
enum Content {
    Text(String),
    Image(Vec<u8>),
}

/// What our own selection serves.
enum Serving {
    Text(String),
    Image(Vec<u8>),
}

/// Things that wake the Wayland loop from other threads.
enum Msg {
    Command(String),
    /// Content read from the selection with this sequence number.
    Read(u64, Content),
    StdinClosed,
}

struct State {
    device: Option<ExtDataControlDeviceV1>,
    manager: ExtDataControlManagerV1,
    offers: HashMap<ObjectId, Vec<String>>,
    history: Vec<Entry>,
    next_id: u64,
    // Our own source while we own the selection, and what it serves.
    source: Option<ExtDataControlSourceV1>,
    serving: Serving,
    tx: mpsc::Sender<Msg>,
    // Bumped on every selection change; a read that finishes after a newer
    // selection must not land on top of the history.
    seq: u64,
    qh: Option<QueueHandle<State>>,
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn store_path() -> PathBuf {
    state_dir().join("clipboard.json")
}

fn images_dir() -> PathBuf {
    state_dir().join("clipboard")
}

/// Decode a copied image and save it as PNG under a name taken from its
/// pixels, so copying the same image again finds the same file.
/// Returns (path, width, height).
fn store_image(bytes: &[u8]) -> Option<(String, u32, u32)> {
    let img = image::load_from_memory(bytes).ok()?;
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    img.as_bytes().hash(&mut hasher);
    (img.width(), img.height()).hash(&mut hasher);
    let path = images_dir().join(format!("{:016x}.png", hasher.finish()));
    if !path.exists() {
        std::fs::create_dir_all(images_dir()).ok()?;
        let tmp = path.with_extension("png.tmp");
        img.save_with_format(&tmp, image::ImageFormat::Png).ok()?;
        std::fs::rename(&tmp, &path).ok()?;
    }
    Some((
        path.to_string_lossy().into_owned(),
        img.width(),
        img.height(),
    ))
}

impl State {
    fn emit(&self) -> bool {
        let json = serde_json::to_string(&self.history).unwrap_or_else(|_| "[]".into());
        let mut out = std::io::stdout().lock();
        writeln!(out, "history {json}")
            .and_then(|()| out.flush())
            .is_ok()
    }

    fn save(&self) {
        if let Ok(json) = serde_json::to_string(&self.history)
            && let Err(e) = write_atomic(&store_path(), &json)
        {
            eprintln!("kshelld clipboard: saving history: {e}");
        }
    }

    fn changed(&mut self) -> bool {
        // Cap the size, dropping the oldest unpinned entries; images have a
        // smaller cap of their own.
        while self.history.len() > MAX_ENTRIES {
            match self.history.iter().rposition(|e| !e.pinned) {
                Some(i) => {
                    self.history.remove(i);
                }
                None => break,
            }
        }
        while self
            .history
            .iter()
            .filter(|e| e.is_image() && !e.pinned)
            .count()
            > MAX_IMAGES
        {
            match self.history.iter().rposition(|e| e.is_image() && !e.pinned) {
                Some(i) => {
                    self.history.remove(i);
                }
                None => break,
            }
        }
        self.prune_images();
        self.save();
        self.emit()
    }

    /// Delete image files no entry points to any more.
    fn prune_images(&self) {
        let Ok(dir) = std::fs::read_dir(images_dir()) else {
            return;
        };
        for file in dir.flatten() {
            let path = file.path().to_string_lossy().into_owned();
            if path.ends_with(".png")
                && !self
                    .history
                    .iter()
                    .any(|e| e.path.as_deref() == Some(&path))
            {
                let _ = std::fs::remove_file(file.path());
            }
        }
    }

    /// Put an entry at the top (or just below it for a stale read), keeping
    /// the pin of an earlier copy of the same thing.
    fn insert(&mut self, mut entry: Entry, stale: bool, same: impl Fn(&Entry) -> bool) -> bool {
        if stale && self.history.iter().any(&same) {
            return true;
        }
        if let Some(i) = self.history.iter().position(&same) {
            entry.pinned = self.history.remove(i).pinned;
        }
        self.next_id += 1;
        entry.id = self.next_id;
        let at = if stale { 1.min(self.history.len()) } else { 0 };
        self.history.insert(at, entry);
        self.changed()
    }

    fn add_image(&mut self, bytes: &[u8], stale: bool) -> bool {
        let Some((path, width, height)) = store_image(bytes) else {
            return true;
        };
        let entry = Entry {
            id: 0,
            kind: "image".into(),
            text: String::new(),
            path: Some(path.clone()),
            width: Some(width),
            height: Some(height),
            pinned: false,
            time: now(),
        };
        self.insert(entry, stale, |e| e.path.as_deref() == Some(&path))
    }

    /// New clipboard text: add it, or move an existing copy to the top.
    /// Stale reads (an older selection) go just below the top instead.
    fn add(&mut self, text: String, stale: bool) -> bool {
        if text.trim().is_empty() || text.len() > MAX_BYTES {
            return true;
        }
        let entry = Entry {
            id: 0,
            kind: text_kind(),
            text: text.clone(),
            path: None,
            width: None,
            height: None,
            pinned: false,
            time: now(),
        };
        self.insert(entry, stale, |e| !e.is_image() && e.text == text)
    }

    fn add_content(&mut self, content: Content, stale: bool) -> bool {
        match content {
            Content::Text(text) => self.add(text, stale),
            Content::Image(bytes) => self.add_image(&bytes, stale),
        }
    }

    /// Serve an entry as the selection again.
    fn restore(&mut self, entry: &Entry, qh: &QueueHandle<Self>) {
        if entry.is_image() {
            if let Some(bytes) = entry.path.as_ref().and_then(|p| std::fs::read(p).ok()) {
                self.set_selection(Serving::Image(bytes), qh);
            }
        } else {
            self.set_selection(Serving::Text(entry.text.clone()), qh);
        }
    }

    fn command(&mut self, line: &str, qh: &QueueHandle<Self>) -> bool {
        let (cmd, arg) = line.trim().split_once(' ').unwrap_or((line.trim(), ""));
        let id: Option<u64> = arg.parse().ok();
        let pos = id.and_then(|id| self.history.iter().position(|e| e.id == id));
        match (cmd, pos) {
            ("copy", Some(i)) => {
                let entry = self.history.remove(i);
                self.restore(&entry, qh);
                // Back to the top.
                self.history.insert(0, entry);
                self.changed()
            }
            ("pin", Some(i)) => {
                self.history[i].pinned = !self.history[i].pinned;
                self.changed()
            }
            ("delete", Some(i)) => {
                self.history.remove(i);
                self.changed()
            }
            ("clear", _) => {
                self.history.retain(|e| e.pinned);
                self.changed()
            }
            _ => true,
        }
    }

    fn set_selection(&mut self, serving: Serving, qh: &QueueHandle<Self>) {
        let Some(device) = &self.device else { return };
        let source = self.manager.create_data_source(qh, ());
        match &serving {
            Serving::Text(_) => {
                for m in TEXT_MIMES {
                    source.offer(m.into());
                }
            }
            Serving::Image(_) => source.offer("image/png".into()),
        }
        device.set_selection(Some(&source));
        self.seq += 1;
        if let Some(old) = self.source.replace(source) {
            old.destroy();
        }
        self.serving = serving;
    }

    /// Read an offer's text on a thread: if the selection is ours, the data
    /// comes from our own `send` handler, which needs this loop running.
    fn read(&mut self, offer: &ExtDataControlOfferV1, conn: &Connection) {
        let mimes = self.offers.remove(&offer.id()).unwrap_or_default();
        if mimes.iter().any(|m| m == SECRET_HINT) {
            offer.destroy();
            return;
        }
        // An image wins over its text (a copied picture often carries a URL too).
        let image = IMAGE_MIMES.iter().find(|m| mimes.iter().any(|x| x == *m));
        let text = TEXT_MIMES.iter().find(|m| mimes.iter().any(|x| x == *m));
        let Some(mime) = image.or(text) else {
            offer.destroy();
            return;
        };
        let is_image = image.is_some();
        let limit = if is_image { MAX_IMAGE_BYTES } else { MAX_BYTES };
        let Ok((mut reader, writer)) = std::io::pipe() else {
            return;
        };
        offer.receive((*mime).into(), writer.as_fd());
        drop(writer);
        let _ = conn.flush();
        offer.destroy();
        let tx = self.tx.clone();
        let seq = self.seq;
        std::thread::spawn(move || {
            let mut buf = Vec::new();
            if reader
                .by_ref()
                .take(limit as u64 + 1)
                .read_to_end(&mut buf)
                .is_err()
                || buf.len() > limit
            {
                return;
            }
            let content = if is_image {
                Content::Image(buf)
            } else {
                match String::from_utf8(buf) {
                    Ok(text) => Content::Text(text),
                    Err(_) => return,
                }
            };
            let _ = tx.send(Msg::Read(seq, content)); // forwarded + loop woken in run()
        });
    }
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for State {
    fn event(
        _: &mut Self,
        _: &wl_registry::WlRegistry,
        _: wl_registry::Event,
        _: &GlobalListContents,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_seat::WlSeat, ()> for State {
    fn event(
        _: &mut Self,
        _: &wl_seat::WlSeat,
        _: wl_seat::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_callback::WlCallback, ()> for State {
    fn event(
        _: &mut Self,
        _: &wl_callback::WlCallback,
        _: wl_callback::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ExtDataControlManagerV1, ()> for State {
    fn event(
        _: &mut Self,
        _: &ExtDataControlManagerV1,
        _: <ExtDataControlManagerV1 as Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ExtDataControlDeviceV1, ()> for State {
    fn event(
        state: &mut Self,
        _: &ExtDataControlDeviceV1,
        event: ext_data_control_device_v1::Event,
        _: &(),
        conn: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            ext_data_control_device_v1::Event::DataOffer { id } => {
                state.offers.insert(id.id(), Vec::new());
            }
            ext_data_control_device_v1::Event::Selection { id: Some(offer) } => {
                state.seq += 1;
                state.read(&offer, conn);
            }
            // Emptied (the app that copied quit): put the newest entry back.
            ext_data_control_device_v1::Event::Selection { id: None } => {
                state.seq += 1;
                if let (Some(entry), Some(qh)) = (state.history.first().cloned(), state.qh.clone())
                {
                    state.restore(&entry, &qh);
                }
            }
            ext_data_control_device_v1::Event::PrimarySelection { id: Some(offer) } => {
                state.offers.remove(&offer.id());
                offer.destroy();
            }
            ext_data_control_device_v1::Event::Finished => state.device = None,
            _ => {}
        }
    }

    event_created_child!(State, ExtDataControlDeviceV1, [
        ext_data_control_device_v1::EVT_DATA_OFFER_OPCODE => (ExtDataControlOfferV1, ()),
    ]);
}

impl Dispatch<ExtDataControlOfferV1, ()> for State {
    fn event(
        state: &mut Self,
        offer: &ExtDataControlOfferV1,
        event: ext_data_control_offer_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let ext_data_control_offer_v1::Event::Offer { mime_type } = event {
            state.offers.entry(offer.id()).or_default().push(mime_type);
        }
    }
}

impl Dispatch<ExtDataControlSourceV1, ()> for State {
    fn event(
        state: &mut Self,
        source: &ExtDataControlSourceV1,
        event: ext_data_control_source_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            ext_data_control_source_v1::Event::Send { fd, .. } => {
                let data = match &state.serving {
                    Serving::Text(text) => text.as_bytes().to_vec(),
                    Serving::Image(bytes) => bytes.clone(),
                };
                std::thread::spawn(move || {
                    let mut file = std::fs::File::from(fd);
                    let _ = file.write_all(&data);
                });
            }
            ext_data_control_source_v1::Event::Cancelled => {
                source.destroy();
                if state.source.as_ref() == Some(source) {
                    state.source = None;
                }
            }
            _ => {}
        }
    }
}

pub fn run(_args: &[String]) -> Result<()> {
    let conn = Connection::connect_to_env().context("no Wayland display")?;
    let (globals, mut queue) = registry_queue_init::<State>(&conn)?;
    let qh = queue.handle();
    let manager: ExtDataControlManagerV1 = globals
        .bind(&qh, 1..=1, ())
        .context("the compositor has no ext-data-control (ext_data_control_manager_v1)")?;
    let seat: wl_seat::WlSeat = globals.bind(&qh, 1..=9, ())?;

    let history: Vec<Entry> = std::fs::read_to_string(store_path())
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();
    let next_id = history.iter().map(|e| e.id).max().unwrap_or(0);
    let (tx, rx) = mpsc::channel();

    let mut state = State {
        device: None,
        manager,
        offers: HashMap::new(),
        history,
        next_id,
        source: None,
        serving: Serving::Text(String::new()),
        tx: tx.clone(),
        seq: 0,
        qh: Some(qh.clone()),
    };
    state.device = Some(state.manager.get_data_device(&seat, &qh, ()));
    if !state.emit() {
        return Ok(());
    }

    // Other threads hand over work through `rx`, then wake the blocking
    // Wayland dispatch with a sync request (its `done` event).
    let waker = {
        let conn = conn.clone();
        let qh = qh.clone();
        move || {
            conn.display().sync(&qh, ());
            let _ = conn.flush();
        }
    };
    {
        let tx = tx.clone();
        let waker = waker.clone();
        std::thread::spawn(move || {
            for line in std::io::stdin().lines() {
                let Ok(line) = line else { break };
                if tx.send(Msg::Command(line)).is_err() {
                    return;
                }
                waker();
            }
            let _ = tx.send(Msg::StdinClosed);
            waker();
        });
    }
    // Reader threads send Msg::Read; wake for them too.
    let (read_tx, read_rx) = mpsc::channel::<(u64, Content)>();
    state.tx = {
        let (fwd_tx, fwd_rx) = mpsc::channel::<Msg>();
        let waker = waker.clone();
        std::thread::spawn(move || {
            for msg in fwd_rx {
                if let Msg::Read(seq, content) = msg {
                    if read_tx.send((seq, content)).is_err() {
                        return;
                    }
                    waker();
                }
            }
        });
        fwd_tx
    };

    loop {
        queue.blocking_dispatch(&mut state)?;
        if state.device.is_none() {
            bail!("data control device finished");
        }
        while let Ok((seq, content)) = read_rx.try_recv() {
            let stale = seq != state.seq;
            if !state.add_content(content, stale) {
                return Ok(());
            }
        }
        while let Ok(msg) = rx.try_recv() {
            match msg {
                Msg::Command(line) => {
                    if !state.command(&line, &qh) {
                        return Ok(());
                    }
                }
                Msg::StdinClosed => return Ok(()),
                Msg::Read(seq, content) => {
                    let stale = seq != state.seq;
                    if !state.add_content(content, stale) {
                        return Ok(());
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn old_history_is_text() {
        let old = r#"[{"id":3,"text":"hello","pinned":true,"time":1}]"#;
        let history: Vec<Entry> = serde_json::from_str(old).unwrap();
        assert_eq!(history[0].kind, "text");
        assert!(!history[0].is_image());
        assert!(history[0].pinned);
    }

    #[test]
    fn image_entries_round_trip() {
        let entry = Entry {
            id: 1,
            kind: "image".into(),
            text: String::new(),
            path: Some("/tmp/x.png".into()),
            width: Some(10),
            height: Some(20),
            pinned: false,
            time: 2,
        };
        let json = serde_json::to_string(&entry).unwrap();
        let back: Entry = serde_json::from_str(&json).unwrap();
        assert!(back.is_image());
        assert_eq!(back.path.as_deref(), Some("/tmp/x.png"));
        assert_eq!((back.width, back.height), (Some(10), Some(20)));
    }

    #[test]
    fn text_entries_leave_image_fields_out() {
        let entry = Entry {
            id: 1,
            kind: text_kind(),
            text: "a".into(),
            path: None,
            width: None,
            height: None,
            pinned: false,
            time: 0,
        };
        let json = serde_json::to_string(&entry).unwrap();
        assert!(!json.contains("path"));
    }
}
