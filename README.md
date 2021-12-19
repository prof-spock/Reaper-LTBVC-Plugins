# Reaper Plugins for the LilypondToBandVideoConverter

## Introduction

The “Reaper Plugins for the LilypondToBandVideoConverter” software
package provides Lua plugins for being used in the [Reaper
DAW][reference:reaper]; they assist in using the
[LilypondToBandVideoConverter][reference:ltbvc]
tool chain for generating notation videos from arrangement text files.

The four scripts provide the following services:

  - *ExportLilypond.lua:* transforms the notes of the selected MIDI
     item into a textual lilypond note/chord sequence and returns them
     in a text box,

  - *ImportMidi.lua:* scans the current project for tracks with single
     MIDI items and replaces those by the corresponding track in an
     associated MIDI file filtering out unwanted midi items before
     import,

  - *MakeRegionsFromStructureTrack.lua:* either makes regions based on
     a region structure track with structural MIDI items or generates
     that structure track with midi items from the current regions,
     and

  - *NormalizeStructuredMidiTracks.lua:* scans all tracks with some
    specific prefix and normalizes their enclosed midi items by
    removing reverb, chorus and delay control codes, setting
    velocities to some default and quantizing the positions and
    lengths

They rely on several additional Lua modules provided in the package.

## Installation

The installation is as follows:

  - Copy the archive from this repository and unpack it to some
    temporary directory.
  
  - Close the Reaper application (if open).

  - Copy the lua-files from the archive subdirectory `src` into the
    `Lua` sub-directory of the Reaper installation (typically into
    `\Program Files\Reaper\Lua` for Windows or
    `/Applications/Reaper.app/Lua` in MacOS).

  - If helpful, also copy the documentation files from the
    archive subdirectory `doc` to the `Lua` sub-directory.

  - Restart Reaper.  You should now be able to access the
    scripts as actions in the Actions menu of Reaper.
    It is helpful to define some keyboard shortcuts for
    those actions for a quicker access.

Alternatively -&nbsp;and much easier!&nbsp;- you can use the
[ReaPack][reference:reapack] plugin and do an automatic install via
the `index.xml` file in this repository.

After the installation via ReaPack all the scripts can be found in the
action list of the Reaper installation via the prefix `LTBVCPlugins_`;
so, for example, the lilypond export script has the action name
`LTBVCPlugins_ExportLilypond.lua`.

## Further Information

A detailed manual is available [here][reference:manual].

[reference:ltbvc]:   https://github.com/prof-spock/LilypondToBandVideoConverter
[reference:manual]:  https://github.com/prof-spock/Reaper-LTBVC-Plugins/raw/master/Reaper-LTBVC-Scripts.pdf.
[reference:reapack]: https://reapack.com/
[reference:reaper]:  https://reaper.fm/
