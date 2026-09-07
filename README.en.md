# PulseLight

[中文](README.md) | English

A macOS edge rail that combines AI-agent status with Token usage.

PulseLight combines the multi-provider quota panel from
[Pulse](https://github.com/qunqin24/Pulse) with the traffic-light interaction
inspired by [AgLight](https://github.com/ryubyte/aglight). It stays as a 6pt
edge strip until you point at it, then expands into the full usage panel.

The expanded state is shown as the original runtime screenshot, with no
resizing into a composite image:

![PulseLight real expanded state](Docs/images/pulselight-expanded-real.png)

The collapsed state has its own enlarged legend, so the real screenshot keeps
its original proportions:

![PulseLight 80/20 collapsed-state legend](Docs/images/pulselight-collapsed-legend.png)

## The 80 / 20 rail

| Area | Colour | Meaning |
| --- | --- | --- |
| Top 80% | Grey | Agent is idle |
| Top 80% | Yellow | Agent is working |
| Top 80% | Flashing red | Your approval or input is needed |
| Top 80% | Green | Agent just completed, kept for 8 seconds |
| Bottom 20% | Green / yellow / red | The tightest visible Token limit |

Usage stays green below 50%, turns yellow at 50%–75%, and red at 75% or more.
The same layout works on the left, right, and top screen edges.

## What it does

- Keeps Pulse's provider rings, account support, and usage detail cards.
- Tracks Claude Code and Codex activity, approvals, and completion events.
- Stores state per session, so one completed task cannot hide another task
  that still needs approval.
- Uses same-executable local hooks instead of an extra HTTP service.
- Preserves existing hooks and makes a `.pulselight-backup` before first edit.
- Uses its own app name, bundle identifier, storage directory, and login item.

## Install

Download `PulseLight-1.0.7.zip` from Releases, unzip it, move
`PulseLight.app` into Applications, and launch it.

The current release is Apple Silicon (arm64), requires macOS 14+, and is
locally signed but not Developer ID notarized. macOS may ask you to approve
the first launch in Privacy & Security.

On first launch, PulseLight merges its hooks into:

- Claude Code: `~/.claude/settings.json`
- Codex: `~/.codex/hooks.json`

Manual hook management:

```bash
/Applications/PulseLight.app/Contents/MacOS/Pulse --install-agent-hooks
/Applications/PulseLight.app/Contents/MacOS/Pulse --uninstall-agent-hooks
```

## Build locally

```bash
swift build -Xswiftc -swift-version -Xswiftc 6
./Scripts/check-localization.sh
./Scripts/bundle.sh --zip
```

With full Xcode, the packaging script builds a universal Intel + Apple Silicon
app. With Command Line Tools only, it builds for the current Mac architecture.

## Credits and license

PulseLight is a derivative of [Pulse](https://github.com/qunqin24/Pulse).
The agent-status interaction is inspired by
[AgLight](https://github.com/ryubyte/aglight). See [NOTICE](NOTICE) and
[CHANGELOG.md](CHANGELOG.md) for attribution and modifications.

Licensed under [Apache License 2.0](LICENSE).
