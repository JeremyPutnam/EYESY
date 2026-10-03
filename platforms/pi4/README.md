# EYESY on Raspberry Pi 4

Runs the EYESY video engine on a Raspberry Pi 4 with HDMI output, a USB microphone and a USB MIDI controller, instead of the original CM3 hardware.

Tested on: Raspberry Pi 4 Model B (8 GB), Raspberry Pi OS 64-bit **Bookworm** desktop, Python 3.11.
Do not use Python 3.12 or later, because the engine uses `imp`, which was removed in 3.12.

## Layout

The modes live in a separate repo cloned **next to** this one. `main.py` finds them by relative path.

```
<workspace>/
├── EYESY/                 this repo
└── EYESY_Modes_OSv3/      modes repo (one folder per mode, each with main.py)
```

User data (config, scenes, screenshots) is kept outside both repos, in `/home/pi/EYESY-data/{System,Scenes,Grabs}`. It is created on first run.

## Setup

```bash
# system packages (from apt, never use bare pip into system Python)
sudo apt install python3-pygame python3-liblo python3-psutil \
                 python3-mido python3-rtmidi libasound2-dev

# repos
git clone https://github.com/JeremyPutnam/EYESY.git
git clone https://github.com/JeremyPutnam/EYESY_Modes_OSv3.git   # private

# venv with system packages visible, plus a working pyalsaaudio
cd EYESY
python3 -m venv --system-site-packages .venv
.venv/bin/pip install --ignore-installed -r platforms/pi4/requirements.txt
```

## Run

```bash
platforms/pi4/run.sh
```

To stop, press Esc in the EYESY window or Ctrl+C in the terminal.

## Audio

- The engine opens the first ALSA card whose name contains `usb pnp sound device` (`engines/python/sound.py`). It opens the raw `hw:` device as 1 channel, 44100 Hz, S16_LE. The mic must support 44100 Hz mono.
- To check the mic outside EYESY:
  ```bash
  arecord -l                                     # find the card number
  arecord -D hw:3,0 -f S16_LE -r 44100 -c 1 -d 5 /tmp/t.wav && aplay /tmp/t.wav
  ```
- If you get "Device or resource busy", another program (PipeWire, a browser, `arecord`) is holding the mic.

## MIDI mapping (Akai MPD32 defaults)

All values can be overridden in `/home/pi/EYESY-data/System/config.json`. Use `-1` to disable a binding.

| Control | Message | Config key | Action |
|---|---|---|---|
| Top dials 1–5 | CC 12–16, ch 1 | `knob1_cc_alt`…`knob5_cc_alt` | Knobs 1–5 (CC 20–24 via `knobN_cc` also work) |
| Dial 6 | CC 17, ch 1 | `gain_cc` | Mic gain (not saved on restart) |
| Pad | note 67, ch 2 | `trigger_note` | Fire a trigger (drives `T -` modes) |
| Pad | note 69, ch 2 | `auto_clear_note` | Trails on/off |
| Pad | note 62 / 64 | hard-coded | Previous / next mode |
| Pad | note 60 | hard-coded | On-screen display |
| Pad | note 65 | hard-coded | Reload current mode |

Pad notes are accepted on `midi_channel` (1) or `pad_channel` (2).
