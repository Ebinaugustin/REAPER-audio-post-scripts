# REAPER Audio Post-Production Scripts

A collection of custom REAPER scripts developed for audio post-production,
film sound, mixing, editing, surround and immersive audio workflows.

---

## SurroundScope Multimeter Dashboard

A ReaImGui-based multichannel audio analysis and metering dashboard for REAPER.

### Features

- Multichannel Peak / RMS metering
- ITU, Film and SMPTE channel layouts
- Stereo, 5.1, 7.1 and 7.1.4 formats
- Scrolling multichannel waveform
- Spectrum analyzer
- Loudness and phase monitoring
- Surround-field visualization
- Detailed channel statistics
- Configurable meter response and peak hold

### Screenshots

#### Multichannel Meters

![SurroundScope Multimeter](Screenshots/meters.png)

#### Waveform

![SurroundScope Waveform](Screenshots/waveform.png)

#### Spectrum

![SurroundScope Spectrum](Screenshots/spectrum.png)

#### Loudness & Phase

![SurroundScope Loudness](Screenshots/loudness.png)

#### Surround Field

![SurroundScope Surround Field](Screenshots/surround-scope.png)

#### Channel Details

![SurroundScope Channel Details](Screenshots/details.png)

### Installation

1. Install [REAPER](https://www.reaper.fm/).
2. Install the ReaImGui extension.
3. Install the `SurroundScope Multimeter Analyzer.jsfx`.
4. Copy `SurroundScope_Multimeter_Dashboard.lua` to your REAPER Scripts folder.
5. Insert the analyzer JSFX on the desired audio path.
6. Set the Dashboard and Analyzer to the same Analyzer Slot.
7. Run the Dashboard script.

### Requirements

- REAPER
- ReaImGui
- SurroundScope Multimeter Analyzer JSFX

### Script

[SurroundScope_Multimeter_Dashboard.lua](Scripts/SurroundScope_Multimeter_Dashboard.lua)
