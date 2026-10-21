# Third-party source notices

The native package's new source is distributed under GNU AGPL version 3 or later. The licence text is in `LICENSE.txt`. The previous standalone script remains outside this native package.

Dependencies are unmodified upstream source snapshots; all original source notices are retained in the offline archives.

- **JUCE 8.0.12**, Raw Material Software Limited: revision `29396c22c93392d6738e021b83196283d6e4d850`, https://github.com/juce-framework/JUCE. Used under the AGPLv3 option described in JUCE's `LICENSE.md`. JUCE's modules contain additional dependencies, including font and image libraries, whose licences are included in the source archive. JUCE provides an alternative commercial licence at https://juce.com/legal/juce-8-licence/.
- **REAPER extension SDK**, Cockos/Justin Frankel: revision `c0eafe87863b2bf69c5c822760f1b32a753b211b`, https://github.com/justinfrankel/reaper-sdk. The SDK's zlib-style licence is retained at `sdk/LICENSE` in its archive.
- **Cockos WDL / SWELL**: revision `d30c30b356b2b7fb1654def8dbda90066f43061a`, https://github.com/justinfrankel/WDL. The used SWELL files carry their zlib-style notices in their headers. Other archived WDL components retain their own notices.

REAPER is a separate host application and is not distributed with this package. The Microsoft compiler, Windows SDK and development utilities used for the local Windows build are not included in the deliverable.
