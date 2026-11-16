# OrbitLog — Session Handover

Read this first in a new chat, then read the backlog artifact (link below) before describing or starting any new work.

## What this project is
- iOS space/astronomy tracker app, published as **OrbitLog**. Xcode project folder is internally named `spaceTracker` — intentional, never user-facing, never rename it.
- Lives on the user's Mac at `spaceTracker/` (path: `/Users/benclary/Documents/swift/spaceTracker`), reached through the Claude desktop app's device bridge (`mcp__remote-devices__device_bash`, mounted at `$HOME/mnt/spaceTracker`). That shell is a sandboxed VM with the folder mounted — not the user's real terminal — so there is no local Xcode build/compile check available there. The user pastes real Xcode build errors back when something breaks.
- Full feature/bug backlog, the source of truth: **https://claude.ai/artifact/NQtZosurx3JsvZBuDVsqoN** (a Claude Artifact). Read it with the Artifact tool before planning new work.

## Standing workflow rules (do not skip)
- Edit Swift files with a Python read-modify-write script: `shutil.copy` to a `.bak` first, `content.count(old) == 1` uniqueness assert before replacing, brace/paren balance check (`content.count("{") - content.count("}") == 0`, same for parens) before writing, `rm -f *.bak` after. Used for every edit this project, no exceptions.
- Show the diff and **wait for explicit go-ahead before running `git commit`** — never auto-commit. Trust is lower here after a stubborn bug needed several unconfirmed guess-and-commit attempts in a row; the user wants to review changes before they land in git.
- Commit with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. Never use `git config`, force-push, or skip hooks.
- **Never make changes beyond what's explicitly requested.** If a fix is adjacent but distinct from what was asked, ask first rather than rolling it in silently.
- **Never touch the iPad / `.regular` size-class view** when working on an iPhone/`.compact` fix, unless the user explicitly asks for the iPad view to change. This has caused real frustration before — always ask before any change that could affect iPad.
- The user edits Swift files directly in Xcode themselves too, outside these sessions — check git log for commits that weren't made here before assuming the last-known state is still accurate.

## Current priority: FEAT-31 (pull-to-refresh on Home Command)
Investigated 2026-11-16, not yet implemented. Context:
- Home Command (`ContentView.swift`) has **no `.refreshable` at all**. Only the Star Gazers tab got pull-to-refresh + a 5-minute periodic timer (FEAT-22, see `refreshStargazerTelemetry()`).
- The confusing "weird wording" the user flagged is `INITIALIZE BACKYARD RADAR`, a button at `ContentView.swift` ~line 946 that renders whenever `satViewModel.visiblePasses` is empty — whether that's because nothing is actually overhead right now (normal) or because the automatic fetch failed. No distinction between the two today. The automatic fetch does already run once at launch (`satViewModel.requestPasses()`, inside Home Command's big startup `.task`), so this button is really just a manual re-trigger for any empty state.
- Plan (not yet confirmed in detail with the user beyond "yes, build pull-to-refresh"): add a real `.refreshable` to Home Command that re-runs the same fetch sequence the launch `.task` already does (satellite passes, location re-resolve, weather/moon data, notification scheduling) — mirror the FEAT-22 pattern (a shared `refreshX()` helper with no `isDataLoaded` guard, reused by both the initial load and the refresh path). **Still open, needs confirming with the user before coding:** whether to also fix the `INITIALIZE BACKYARD RADAR` wording/behavior in the same pass (reword it, and make a genuine "nothing overhead right now" read as informational rather than as an error to retry), since that's adjacent but technically a separate concern from pull-to-refresh itself.

## Also just added to the backlog (2026-11-16), for later
Two new stickiness/daily-engagement feature proposals, not yet discussed in detail or scoped — see the artifact for full writeups:
- **FEAT-32** — personal observation log + streaks (tap "I saw it" on a card, build a local sighting history, streak counter, milestones).
- **FEAT-33** — proactive "clear skies tonight" notification, using the stargazing conditions score the app already computes, instead of only the fixed 08:00 daily briefing.

## Other open items worth knowing about
- **BUG-03** (iPad top tab bar only shows 3 of 4 tabs) — in-progress, not root-caused. Source code for the original fix (`Tab()` API + `.tabViewStyle(.sidebarAdaptable)`) is confirmed still intact; the user suspects the top bar area is trying to show too much at once.
- **BUG-06** (APOD ambient background) — in-progress, needs on-device confirmation of the latest fix.
- **BUG-07, BUG-09, BUG-10, BUG-11, BUG-12** — all backlog, not started. BUG-12 in particular found a real freshness gap (nothing refreshes time-sensitive data on app-foreground or first-tab-open, only an in-tab timer or manual pull) that's closely related to FEAT-31's own fix.
