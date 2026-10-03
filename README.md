# EYESY_OS

The operating system for the EYESY video synthesizer device.

* engines, generally a video engine takes audio, midi, and control messages as input and outputs video
* web, a web based editor and file manager

* platforms, setup files per hardware: `eyesy_cm3` (original EYESY), `pi4` (Raspberry Pi 4)

## This fork: Raspberry Pi 4

This fork runs EYESY on a Raspberry Pi 4 with HDMI output, a USB microphone, and a USB MIDI controller (Akai MPD32).
Setup, the run command, and the MIDI mapping are in [platforms/pi4/README.md](platforms/pi4/README.md).
Notes for AI coding agents are in [AGENTS.md](AGENTS.md).

Modes are kept in a separate repo, cloned next to this one as `EYESY_Modes_OSv3/`.
