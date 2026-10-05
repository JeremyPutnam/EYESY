# AGENTS.md

Context for AI coding agents working on this repo. Paths are relative to the repo root unless they are absolute. Facts were checked on the target Pi on 2026-10-03.

## Overview
- Goal: run EYESY_OS (the Critter & Guitari video synth) on a Raspberry Pi 4 instead of its original CM3 hardware. HDMI output, USB mic, USB MIDI (Akai MPD32).
- Two repos, cloned side by side in one workspace folder (on the Pi: `/home/pi/Visualizer/`):
  - **This repo** (`EYESY/`)
    - `origin` = github.com/JeremyPutnam/EYESY (public). This is a standalone copy of upstream EYESY_OS history, not a GitHub fork.
    - The engine, the web editor (unused), and platform files live here.
  - **Modes repo** (`../EYESY_Modes_OSv3/`)
    - `origin` = github.com/JeremyPutnam/EYESY_Modes_OSv3 (**private**).
    - `upstream` = critterandguitari/EYESY_Modes_OSv3 (push disabled). Pull new upstream modes with `git pull upstream main`.
    - About 108 modes, one folder each.
- `engines/python/main.py` starts the audio subprocess (`sound.py`), opens MIDI (`midi.py`), loads every mode, then runs a pygame loop at 30 fps that calls the current mode's `draw()`.
- Input on the Pi comes from USB MIDI and the keyboard (keys 1–0 → `dispatch_key_event`, `main.py:40-71`). The CM3's OSC hardware controls (`osc.py`, `hw_controls`) are disabled in this fork.
- `web/` (Flask on port 8080) is **not used**. The owner controls everything by MIDI.

## Environment (verified)
- Raspberry Pi 4 Model B Rev 1.4, 8 GB, `aarch64`, kernel 6.12 `rpt-rpi-v8`.
- Raspberry Pi OS 64-bit **bookworm** desktop, Wayland (`labwc`). pygame opens fullscreen 1920x1080 on HDMI.
- Python **3.11.2** is the system Python. **Do not upgrade the OS or Python, and do not switch to Trixie.** The engine uses `import imp` (`eyesy.py:6`), which was removed in Python 3.12.
- **Run the engine with the venv** (`.venv/`, gitignored, created with `--system-site-packages`):
  - It contains pyalsaaudio ≥ 0.9 (`platforms/pi4/requirements.txt`).
  - apt `python3-alsaaudio` 0.8.4 crashes on `pcm.read()` under Python 3.10+, so running with plain `python3` gives silent audio.
- Everything else comes from apt: `python3-pygame` 2.1.2, `python3-mido` 1.2.10, `python3-rtmidi`, `python3-liblo`, `python3-psutil`, `libasound2-dev`.
- Full setup steps: `platforms/pi4/README.md`.

## Directory map
```
AGENTS.md                      this file (workspace root has a symlink to it)
engines/python/main.py         entry point; data and mode paths at lines 80-85
engines/python/eyesy.py        state, DEFAULT_CONFIG and validation, mode/scene loading, keys
engines/python/sound.py        ALSA capture subprocess (USB mic)
engines/python/midi.py         MIDI input and mappings (_handle_note, _handle_control_change)
platforms/pi4/                 Pi 4 platform: README (setup, boot, MIDI table), run.sh, eyesy.service, autostart .desktop
platforms/eyesy_cm3/           upstream CM3 reference only; NOT deployed (see Rules)
web/                           Flask editor, unused on the Pi
../EYESY_Modes_OSv3/<Mode>/    one mode per folder: main.py (+ optional assets)
/home/pi/EYESY-data/           user data, outside both repos: System/config.json, Scenes/, Grabs/
```

## Commands
EYESY starts at boot as a systemd **user** service:
- `~/.config/autostart/eyesy.desktop` runs `systemctl --user start eyesy` once the autologin desktop is up.
- Both that file and the unit are symlinks to `platforms/pi4/`.
```bash
systemctl --user {start|stop|restart|status} eyesy
journalctl --user-unit eyesy -f              # logs (journal is volatile, lost on reboot)
platforms/pi4/run.sh                         # run by hand; stop the service first
```
- **Only one engine at a time.** A second instance gets `ALSAAudioError: Device or resource busy [hw:3]` and runs silent.
- Before running the engine for a test, check `systemctl --user is-active eyesy` and stop it if it is running. Restore it afterwards.
- `Restart=on-failure`: Esc (exit 0) stays stopped, while a crash or a video resolution change (exit 1) restarts.
- The CM3 units (`eyesypy`, etc.) assume `/home/music/EYESY_OS`. Do not install them.

Syntax-check modes. `PYTHONPYCACHEPREFIX` keeps `__pycache__` out of the repo:
```bash
PYTHONPYCACHEPREFIX=/tmp/pyc python3 -m py_compile "../EYESY_Modes_OSv3/S - Oscilloscope/main.py"
for f in ../EYESY_Modes_OSv3/*/main.py; do PYTHONPYCACHEPREFIX=/tmp/pyc python3 -m py_compile "$f" || echo "FAIL $f"; done
```
Audio tests. The mic was card 3 on 2026-10-03, but card numbers can change, so run `arecord -l` first:
```bash
arecord -l
arecord -D hw:3,0 --dump-hw-params -d 1 /dev/null
arecord -D hw:3,0 -f S16_LE -r 44100 -c 1 -d 5 /tmp/t.wav && aplay /tmp/t.wav
```
Find out what a MIDI control sends: open every `mido.get_input_names()` port containing `MPD32`, then print `iter_pending()` messages while the user moves the control. This is how all current mappings were captured.

## Audio notes
- USB mic: `USB PnP Sound Device` (C-Media). Its hardware supports **mono only, S16_LE only, 44100 or 48000 Hz**.
- `sound.py`:
  - Finds the card by name match on `"usb pnp sound device"` (`sound.py:16-28`). If nothing matches, the audio process exits and the engine keeps running silent.
  - Opens `alsaaudio.PCM(..., cardindex=N, channels=1, rate=44100, format=S16_LE, periodsize=256)` (`sound.py:42-50`). The log shows `PCM handle name = 'hw:3'`, the raw device, which is exclusive and does no conversion.
  - Treats the input as mono: left and right get the same samples (`sound.py:66-67`).
  - Averages every 16 samples into a 100-slot shared buffer, which modes read as `etc.audio_in` (`sound.py:71-96`).
- Gain multiplier is `g*g*50 + 1`, where g is `audio_gain` from 0 to 1 (`main.py:268`). It scales `audio_in` only. Peaks are raw.
- Audio trigger fires when the raw peak is above 20000 and `trigger_source` is 0 or 2 (`main.py:273-274`). The `atrig` variable is unused.
- **PipeWire risk:** `pipewire`, `pipewire-pulse`, and `wireplumber` run as user services. If anything else holds the mic, the engine's open fails with "Device or resource busy". No `~/.asoundrc` or `/etc/asound.conf` exists.

## Modes and scenes
- Paths (`main.py:80-85`):
  - `MODES_PATH` = `EYESY_Modes_OSv3/` next to this repo (resolved relative to `main.py`).
  - `GRABS`, `SCENES`, and `SYSTEM` = `/home/pi/EYESY-data/...`, created by `eyesy.ensure_directories()` (`main.py:91`).
  - `/sdcard` and `/usbdrive` (the upstream defaults) do not exist on the Pi.
- Loading (`eyesy.py:492-508`):
  - Every non-hidden subfolder is loaded with `imp.load_source(folder_name, folder/main.py)`, sorted case-insensitively.
  - A mode that fails to load is logged and skipped.
  - Config `mode_order` (a list of folder names) loads those modes first, in that order, and the engine starts on the first one. It is currently set to the four new modes (Prism Rings, Spectrum Ribbons, Color Bloom, Shard Grid). Unknown names are ignored.
  - `setup()` runs for every mode at startup (`main.py:162-177`).
- Mode API: `setup(screen, etc)` and `draw(screen, etc)`, where `etc` is the `Eyesy` object.
  - Inputs: `etc.knob1`…`knob5` (0–1), `etc.audio_in[0..99]` (int16 range), `etc.audio_peak`, `etc.trig` (True for one frame), `etc.xres`/`yres`, `etc.midi_notes`.
  - Helpers: `etc.color_picker(v)`, `etc.color_picker_bg(v)`, `etc.color_picker_lfo(v, rate)`.
- Knob conventions (from the header comments in 106 modes):
  - Knob 4 = foreground color, Knob 5 = background color.
  - Knobs 1–3 vary by mode (usually position, then size or effect).
  - `T -` modes (27 of 29) only animate on `etc.trig`.
- Adding a mode:
  - Create `../EYESY_Modes_OSv3/S - Name/main.py` (or `T - Name`), run py_compile, and restart the engine. Commit it in the modes repo.
  - Key 9 or MIDI note 65 reloads the current mode live.
- Scenes are saved in `Scenes/` and recalled by program change through `pc_map` in config. None are saved yet.

## MIDI (Akai MPD32)
- Config keys are in `eyesy.py` DEFAULT_CONFIG and validated in `validate_config`. Missing keys in `config.json` fall back to the defaults.
- `knobN_cc` (20–24) **and** `knobN_cc_alt` (12–16, the top dials) both drive knob N.
- `gain_cc` 17 sets `audio_gain` in memory only (not saved).
- `fg_palette_cc` 18 and `bg_palette_cc` 19 choose the palette as `val * len(palettes) // 128` (upstream used `% len`, which wrapped 3 times). These are also in memory only.
- Pads send on **channel 2**. `_handle_note` accepts pad actions on `midi_channel` (1) or `pad_channel` (2):
  - 60 = on-screen display, 62/64 = previous/next mode, 65 = reload (these four are hard-coded).
  - `trigger_note` 67 fires `etc.trig`.
  - `auto_clear_note` 69 toggles trails.
- Full table: `platforms/pi4/README.md`. When mappings change, update that table, this section, and DEFAULT_CONFIG/validation together.

## Conventions and rules
- Never run a bare `pip install` into system Python, and never use `--break-system-packages` (upstream does; do not copy it).
  - Use apt, or `.venv/bin/pip install` (add `--ignore-installed` to shadow an apt package).
- No `sudo` unless it is required, and state why when you use it.
- Edit only this repo, the modes repo, and `/home/pi/EYESY-data/`. Ask before touching anything else.
- **Ask first, and back up the original** (`cp f f.bak.$(date +%F)`) before changing:
  - systemd units (including `platforms/eyesy_cm3/deploy.sh` and `disable_services.sh`, which mask ssh and avahi and assume a `music` user)
  - `~/.asoundrc` and `/etc/asound*`
  - PipeWire or WirePlumber config
  - `/boot/firmware/*` (never copy `platforms/eyesy_cm3/boot/`)
  - `/etc/fstab`
- Git:
  - Engine changes are committed here; mode changes are committed in the modes repo.
  - This repo is **public**: no secrets, network details, or large binaries.
  - Ask before pushing.
  - git `user.name`/`user.email` are not configured on the Pi.
- Match the surrounding code style (`if x :` spacing, short comments). Keep mode changes compatible with stock EYESY.

## Known issues and open questions
- UNVERIFIED: whether the mic's card index stays at 3 across reboots. The engine matches by name, but the shell commands use `hw:3,0`.
- UNVERIFIED: whether the 20000 audio-trigger threshold suits this mic. Raw peaks were about 3,200–3,600 in a quiet room, so pads are the reliable trigger.
- Not implemented: loading modes from a USB drive (planned; it would use the udisks auto-mount at `/media/pi/<label>/Modes/` and fall back to the sibling repo).
- Not implemented: the web editor. `/reload_mode` sends OSC, which is disabled, and the editor expects `/sdcard` and needs `flask_sock`.
