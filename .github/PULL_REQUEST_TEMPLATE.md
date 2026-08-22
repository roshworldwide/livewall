<!-- Thanks for contributing. Keep this short — a few lines is fine. -->

## What this changes

<!-- One or two sentences. Link the issue if there is one. -->

## Why

<!-- The problem being solved, not the diff. -->

## Tested on

- macOS version:
- Chip (Apple silicon / Intel):
- Number of displays:

<!--
Multi-display behaviour is the most common source of regressions. If you only
have one screen, say so — it's useful information, not a blocker.
-->

## Checklist

- [ ] Builds clean (`bash Scripts/build.sh`)
- [ ] UI changes include a screenshot or recording
- [ ] New pause conditions go through `updatePlayback(for:)` rather than calling `play()`/`pause()` directly
- [ ] The UI still writes to `Preferences` rather than calling the engine directly
