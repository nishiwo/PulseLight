# I merged Token usage and an AI traffic light into a 6px edge rail

[中文版](introducing-pulselight.md) | English

When I use Claude Code and Codex together, I want two answers without opening
another window: is an agent waiting for me, and how much quota is left?

Pulse already answered the second question with a compact floating usage
panel. AgLight had a clear answer for the first one: a traffic light. I built
PulseLight to make those two signals share one quiet place on the screen edge.

The final visual combines the real expanded screenshot with the collapsed
80/20 state explanation:

![PulseLight final visual](../images/pulselight-effect.png)

## Why 80 / 20

The collapsed rail is only 6pt wide, so every colour needs a single meaning.
The top 80% is agent state: grey for idle, yellow for working, flashing red
for an approval request, and green for eight seconds after completion. The
bottom 20% remains the Token signal: green when comfortable, yellow when it
needs attention, and red when the tightest visible limit is close.

Agent state takes most of the space because it asks for an immediate action.
Quota changes slowly, but it should stay visible. Moving the pointer onto the
rail still opens Pulse's full account rings and detail cards.

## Accurate state without another server

Transcript tails are useful for deciding whether Claude Code or Codex is still
working, but they cannot reliably tell us that an approval is waiting. So
PulseLight installs local hooks for events such as `PermissionRequest`,
`PreToolUse`, and `Stop`.

Each hook calls the PulseLight executable itself, writes one tiny local state
record, and exits. There is no second menu-bar app and no permanent local HTTP
server to manage.

State is saved per session. The final rail colour follows a simple priority:

`needs attention > working > just completed > idle`

That prevents a completed task in one terminal from hiding an approval request
in another.

## Safe configuration changes

Developer configuration is personal, so PulseLight does not replace a whole
Hook file. It removes and refreshes only its own entries, preserves unrelated
commands, and writes a `.pulselight-backup` before the first edit. If the app
moves, its next launch repairs the executable paths.

## Open source

Source: <https://github.com/nishiwo/PulseLight>

PulseLight is derived from [Pulse](https://github.com/qunqin24/Pulse), and
its traffic-light interaction is inspired by
[AgLight](https://github.com/ryubyte/aglight). Thanks to both projects and
their contributors.
