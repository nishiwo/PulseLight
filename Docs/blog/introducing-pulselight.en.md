# One 6px rail tells you what your AI is doing—and how much Token is left

[中文版](introducing-pulselight.md) | English

When an AI task runs in the background, you usually need two answers:

**Is it still working? And how much quota do I have left?**

PulseLight puts both answers in one quiet 6px edge rail. It stays nearly invisible until you need it: read the colour at a glance, then hover to open the full usage panel.

![PulseLight final visual](../images/pulselight-effect.png)

## The 80 / 20 rule

The rail has two jobs:

- **Top 80%: agent state**
  - Grey: idle
  - Yellow: working
  - Flashing red: approval or input needed
  - Green: just completed
- **Bottom 20%: Token health**
  - Green: plenty of quota
  - Yellow: getting close to the limit
  - Red: quota is tight

Agent state gets most of the rail because it tells you whether to come back now. Quota changes more slowly, so a smaller persistent signal is enough.

## Never miss an approval while working in the background

PulseLight watches Claude Code and Codex together. Running, waiting for permission, completed, and idle states are reflected immediately in the rail.

When several terminals are active, an approval request always wins over a completed task. One finished session cannot hide another session that needs your attention.

## Hover once for the complete quota view

There is no second menu-bar icon and no extra monitoring window. Hover over the rail and Pulse's full usage panel opens with:

- Multiple accounts and providers
- Five-hour, weekly, and other quota windows
- Usage percentage, remaining quota, and reset times
- Pulse's existing rings and detail cards

It stays quiet when collapsed and informative when expanded. Dock it to the left, right, or top edge of the screen.

## Try it

PulseLight is a macOS app for Apple Silicon and macOS 14+. Source and releases are available on GitHub:

<https://github.com/nishiwo/PulseLight>

It is derived from [Pulse](https://github.com/qunqin24/Pulse), with the status-light interaction inspired by [AgLight](https://github.com/ryubyte/aglight).

If you leave AI tasks running in the background, PulseLight is designed to answer both questions with one glance: **should you come back now, and how much longer can you keep going?**
