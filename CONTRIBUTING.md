# Contributing to LiveWall

Thanks for wanting to help. LiveWall is small and deliberately stays that way,
so most contributions are quick to review.

## Getting set up

```bash
git clone https://github.com/roshworldwide/livewall.git
cd livewall
open LiveWall.xcodeproj      # then ⌘R
```

No dependencies, no package manager, no `pod install`. The project ad-hoc signs
itself, so you don't need an Apple Developer account.

To produce a DMG the way CI does:

```bash
bash Scripts/build.sh
```

## How the code is arranged

Read `WallpaperEngine.swift` first — it's the heart of the app, and everything
else orbits it.

| Directory | What lives there |
|---|---|
| `LiveWall/Engine/` | The desktop-level window, the `AVPlayerLayer` host, and the engine that owns one output per display |
| `LiveWall/Model/` | Library persistence, video metadata, thumbnail generation |
| `LiveWall/Support/` | Preferences, paths, login-item wrapper |
| `LiveWall/UI/` | Menu bar controller and the SwiftUI window |

### The one architectural rule

**Data flows in one direction.** The UI never talks to the engine directly. It
writes to `Preferences`, which posts `.liveWallPreferencesChanged`, and
`WallpaperEngine.syncFromPreferences()` reconciles every display against that
new state.

If you find yourself wanting to call a method on the engine from a view, add a
property to `Preferences` instead. This is what keeps multi-display state from
drifting, and it's the thing most likely to be asked about in review.

## Things worth knowing before you change the engine

- **Window level.** The wallpaper sits at `desktopIconWindow - 1`. One level up
  and it covers desktop icons; several levels down and the static desktop
  picture covers it.
- **One player per display.** `AVPlayerLayer` can only be bound to one
  `AVPlayer` at a time. Mirroring loads the asset twice on purpose — sharing a
  player makes the second display go black.
- **Looping.** `AVPlayerLooper` pre-enqueues copies of the item so the loop
  point has no gap. Seeking on `AVPlayerItemDidPlayToEndTime` looks fine in
  testing and produces a visible black flash in real use. Please don't switch
  back to it.
- **Battery.** Anything that keeps the GPU decoding when the desktop isn't
  visible is a regression. `updatePlayback(for:)` is the single gate — route new
  pause conditions through it rather than calling `play()`/`pause()` directly.

## Style

Match what's already there. In short: Swift API Design Guidelines, `// MARK:`
sections, and comments that explain *why* rather than restating the code.

## Pull requests

- One logical change per PR.
- Say what you tested on — macOS version, chip, and how many displays. Multi-display
  bugs are the most common regression and the hardest to catch on one screen.
- Include a before/after screenshot or a short screen recording for anything visual.
- CI has to be green. It builds on a clean macOS runner and checks the bundle.

## Good first issues

- Pause on battery / Low Power Mode (`updatePlayback(for:)` already has the gate)
- Playlists and shuffle (`AVQueuePlayer` is already in place)
- Time-of-day switching (write a different id into `Preferences.globalVideoID`)
- Crossfade between wallpapers (`WallpaperContentView.crossfade()` is a stub to build on)
- Global hotkey for play/pause

## Reporting bugs

Use the issue template — it asks for macOS version, display count, and video
codec, which together explain the large majority of reports.
