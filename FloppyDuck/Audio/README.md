# Floppy Duck Audio

This folder is the complete audio handoff point for QA and implementation.

## Runtime Audio

- `Music/`: bundled gameplay and menu music.
  - `action_*` and `adventure_*` are menu or pack tracks.
  - `theme_<theme>` files are per-theme gameplay loops. Most are `.m4a`; `.mp3` is also supported by `SoundManager`.
- `Quacks/`: bundled duck quack sounds.
  - `quack_1.m4a` through `quack_5.m4a` are classic gameplay quacks.
  - `Quacks/Skins/quack_<skin>.m4a` are skin-specific quacks.
- `SFX/`: bundled sound effects.
  - `quack.wav` is the splash/tap quack.
  - `multiplayer_countdown.wav` is the multiplayer countdown cue.
  - `cruchh.m4a` is the bread pickup sound currently loaded by `SoundManager`.
  - `crunch.wav` is retained with the runtime SFX set for review/reference.
- `CREDITS.txt`: third-party and license notes for bundled audio.

## QA Source Audio

`QA_Source/` contains tracked source takes, candidate clips, and reference videos. These are not the canonical runtime files unless code explicitly loads them.

Naming convention:

- `music_<description>.<ext>` for music references.
- `quack_<skin>_source.<ext>` for skin quack source takes.
- `sfx_<description>_candidate.<ext>` for candidate sound effects.
- `video_quack_<skin>.mov` for reference captures tied to quack production.
- `.asd` files are Ableton analysis/metadata sidecars for the adjacent audio file.

## QA Checklist

- Confirm each runtime file is intentional, audible, and not clipped.
- Compare `QA_Source/` takes against their corresponding runtime exports.
- Flag any runtime file whose name does not match the skin, theme, or effect it represents.
- Keep replacement runtime files in the existing runtime folder and filename unless code and Xcode references are updated in the same change.
