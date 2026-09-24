# REAPER Audio Post Scripts

A collection of custom scripts, JSFX, and tools developed for **REAPER**, with a focus on audio post-production, film sound, mixing, surround, immersive audio, and workflow automation.

---

# SurroundScope Multimeter

A multichannel audio analysis and metering system for REAPER, designed for **audio post-production, surround, and immersive audio workflows**.

SurroundScope Multimeter consists of two components:

- **SurroundScope Multimeter Analyzer** — JSFX analysis engine
- **SurroundScope Multimeter Dashboard** — ReaImGui visualization interface

The analyzer performs the audio analysis and publishes the data through REAPER's `gmem` system. The dashboard reads that data and provides a real-time analysis interface.

---

## Features

### Multichannel Metering

- Up to **64 REAPER channels**
- Peak metering
- RMS metering
- Peak hold
- Crest factor
- Sample peak
- Adjustable meter response
- Horizontal and vertical meter layouts
- Multiple meter scale presets

### Waveform Display

- Real-time multichannel waveform/envelope display
- Supports waveform visualization for up to **24 channels**
- Adjustable waveform update rate
- Multiple waveform display themes
- Smooth rolling waveform visualization
- Vertical and horizontal display modes
- Transport-aware scrolling

### Spectrum Analyzer

- 20 Hz – 20 kHz frequency range
- 48 logarithmic frequency bands
- Spectrum smoothing
- Peak hold
- Real-time spectrum visualization

### Loudness & Phase

- Momentary loudness
- Short-term loudness
- Integrated loudness
- Peak
- RMS
- Crest factor
- L/R correlation
- Loudness history display

The analyzer implements **BS.1770-style K-weighting** for its loudness analysis.

> The loudness measurements are analysis estimates. For compliance and delivery, use an approved standards-compliant loudness meter.

### Surround Field

Visualizes energy distribution across multichannel and immersive speaker layouts.

Supported speaker positions include:

- L
- R
- C
- LFE
- Ls
- Rs
- Lrs
- Rrs
- Ltf
- Rtf
- Ltr
- Rtr

The scope provides:

- Surround energy visualization
- Speaker-position visualization
- Energy centroid
- Surround width
- Field focus

### Channel Details

Detailed per-channel information including:

- Channel
- Peak
- RMS
- Hold
- Crest
- Sample peak

---

# Components

## 1. SurroundScope Multimeter Analyzer

**File:**

```text
JSFX/SurroundScope_Multimeter.jsfx
