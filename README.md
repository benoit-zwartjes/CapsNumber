# CapsNumber

**Caps Lock on = digits on the number row.** For Macs with an AZERTY keyboard
(Belgian or French), where the number row normally types `&é"'(§è!çà` and you
need Shift for every digit.

| Caps Lock | You press          | You get |
|-----------|--------------------|---------|
| off       | `é`                | `é` (nothing changes) |
| on        | `é`                | `2` |
| on        | Shift + `é`        | `É` (the symbol, as Caps Lock normally gives it) |

That is all it does. Letters still become uppercase with Caps Lock, shortcuts
with Cmd, Ctrl or Option are untouched, and every other key behaves as before.

## Install

Open **Terminal** (press Cmd + Space, type `Terminal`, press Return), paste this
line and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/benoit-zwartjes/CapsNumber/main/install.sh | bash
```

Then give it permission. macOS shows a prompt about Accessibility:

1. Click **Open System Settings** (or open **System Settings > Privacy & Security > Accessibility** yourself).
2. Switch on **CapsNumber**.

Turn Caps Lock on and type on the number row. Done.

Requirements: macOS 13 Ventura or later, Apple Silicon or Intel. No other
software needed. You can [read the install script](install.sh) before running it.

## What the installer does

- Downloads the latest release of `CapsNumber.app` and puts it in `~/Applications`.
- Registers it to start at login (a small file in `~/Library/LaunchAgents`), so it
  keeps working after a restart.
- Starts it right away.

macOS may show a notification saying a background item was added. That is
this. You can see it under **System Settings > General > Login Items & Extensions**.

## Settings to know about

- **Accessibility permission is the only setting it needs.** Without it, nothing
  happens. It is used to see and adjust keystrokes on the number row, nothing else.
- **No change to your keyboard layout.** Keep Belgian, French or ABC-AZERTY,
  it works with all of them because it acts on the physical keys.
- **Caps Lock must still be Caps Lock.** If you changed it to another key in
  System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys, set it back.
- **Updating:** run the install line again. macOS then asks for the Accessibility
  permission once more, because the app changed. Switch CapsNumber on again and
  you are done.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/benoit-zwartjes/CapsNumber/main/uninstall.sh | bash
```

This also removes its Accessibility permission.

## Troubleshooting

- **Nothing happens with Caps Lock on.** Check that CapsNumber is switched on
  in System Settings > Privacy & Security > Accessibility. Then look at
  `~/Library/Logs/CapsNumber.log`: it should end with "CapsNumber is running".
- **The log says waiting for permission.** Switch CapsNumber off and on in the
  Accessibility list. If that does not help, run the install line again: it
  clears the old permission and macOS shows a fresh prompt.
- **Is it running?** In Terminal:
  `launchctl print gui/$(id -u)/be.benoit.CapsNumber | grep state`

## Privacy

CapsNumber does not record, store or send anything. It has no network code and
no settings. The whole program is one Swift file of about 150 lines,
[Sources/main.swift](Sources/main.swift), which you can read.

## How it works

A tiny native background helper watches key events. When Caps Lock is on and
one of the ten number-row keys is pressed, it flips the Shift flag on that
event before the app receives it. Shift is what turns `é` into `2` on AZERTY,
so the app simply sees a digit.

## Build from source

You need Xcode or the Xcode Command Line Tools.

```bash
git clone https://github.com/benoit-zwartjes/CapsNumber.git
cd CapsNumber
./install.sh
```

`./build.sh` alone produces `build/CapsNumber.app` (universal binary), and
`build/CapsNumber.app/Contents/MacOS/CapsNumber --self-test` checks the logic
against your active keyboard layout.

## License

[MIT](LICENSE)
