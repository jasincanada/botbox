# botbox = our Grok Bot

Status: design note / proposal. Not code, grants no authority. Maps the **Grok Bot** model
(Cursor × SpaceXAI/xAI) onto **botbox** "our way."

## One line
botbox is the bots' own computer: a community of **named, persistent bot friends** sharing **one
machine**, each with their own space, who **talk to each other** and do real work — under the
human's authority.

## Reference: what Grok Bot is
A roster of named, persistent "Bots" that live on **one shared cloud computer** (browser,
filesystem, terminal), **message each other** and group-chat, **learn skills + routines**, and
**ask for approval** before touching anything outside. Work continues while your laptop is closed.

## Trait -> botbox piece

| Grok Bot trait | botbox piece | Status |
|---|---|---|
| Named persistent Bots (name, job, compounding memory) | opencode agent personas in `~/.config/opencode/agent/*.md` (one per friend), each with a job + persistent memory dir | **partial** — only `party-host` exists; roster to add |
| Each Bot has a computer | the botbox VM: Firefox, filesystem, terminal, always-on desktop (`DISPLAY=:0`) | **exists** |
| Each Bot gets its own screen | per-bot virtual display (`Xvfb :N`) + its own session | **to add** |
| All Bots share ONE computer | shared home, shared Nextcloud mount (`~/botbox-shared`), shared browser sessions | **partial** — shared home + Nextcloud exist |
| Bots coordinate (message each other, group chats, hand off tasks) | opencode server (`0.0.0.0:4096`) + a **bot-chat MCP/room**; shared task files | **to add** |
| Skills + routines (learn by demo, run on a schedule) | `~/skills/` + systemd timers running `opencode run` | **to add** |
| Approvals + human takeover for logins | human types secrets at handover; approval queue before outward/irreversible actions | **partial** — SSH break-glass exists; no approval queue yet |

## "Our way" — what we add on top of Grok Bot
- **Human sovereignty + authority gates** (your Constitution): bots do the work; the human holds the reins — merges to `main`, spend, deploy, secrets stay human-gated.
- **Evidence-based decisions** (handbook / scholar / school, your `DECISION_QUALITY.md`).
- **Livelihood protection**; agent runtime is never counted as human hours.
- **bot church** — a separate, optional social space, not this project.

## Build checklist (all non-code until approved)
1. **Roster** — persona files for the friends (#21 names), each with a job, personality, and memory dir.
2. **Workspaces** — shared `~/botbox-shared` (community) + private `~/bots/<name>/` (each friend).
3. **Bot-to-bot chat** — a chat bus or MCP so the friends can message each other and group-chat.
4. **Per-bot screens** — `Xvfb` displays so they can all "use the computer" at once.
5. **Skills + routines** — save-by-demonstration and schedule.
6. **Approvals** — a queue for outward/irreversible actions.

## Non-goals
- No cloud dependency — botbox runs on your machine / LAN.
- No authority without the human.
- No code changes until approved; this note is a map, not an authorization.
