# Phone mirroring

**droid Phone** shows your Android phone's screen in a window and lets you
use it with your mouse and keyboard, like macOS's iPhone Mirroring. It uses
[scrcpy](https://github.com/Genymobile/scrcpy) and adb underneath.

```sh
./install.py packages -g phone   # scrcpy and adb
just apps-install                # droid Phone, if it isn't installed yet
```

Open it from the launcher, or from the **Phone** tile in the dashboard's
Quick Settings.

## Set up the phone (once)

1. **Settings → About phone**, then tap **Build number** seven times to turn
   on Developer options.
2. **Settings → System → Developer options**: turn on **USB debugging**, and
   **Wireless debugging** to connect without a cable.

## Connect

- **USB**: plug the phone in and accept the "Allow USB debugging?" prompt on
  it. It appears in the list.
- **Wi-Fi**: the phone and the computer must be on the same network (the
  computer can be wired). In droid Phone, **Pair over Wi-Fi**, then on the
  phone: Wireless debugging → **Pair device with QR code**, and scan the code.
  Or use **Pair device with pairing code** and type the address and code.

## Use it

- **Mirror** opens the phone's screen in a window: click, type and scroll on
  it. Options: phone audio on the computer, keep the phone awake, turn the
  phone's screen off while mirroring, window always on top.
- **Send files**: drop files on droid Phone (or *Send files…*); they land in
  the phone's Download folder.
