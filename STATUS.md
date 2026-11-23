# Status — Don't Look Backstage

_Updated 2026-11-23, at the end of Phase 4. Every phase of the brief is built; what's left needs
a published place, real IDs, or hands on real devices._

## Where things are

| Phase | What | PR |
| --- | --- | --- |
| 0 | Audit, STATUS.md, line-ending fix | #14 (merged) |
| 1 | Studio playtest of stages 1–3 (no code fixes needed) | #16 |
| 2A | Mannequin overhaul: pose copy, reach, head tilt, Copycat / Shortcut / Mirror / Understudy, "Don't Look" stare rule | #17 |
| 2B | Six stages: + The Flies, The Prop Room, Opening Night, each with a signature scare | #18 |
| 2C | Modes: Story, Daily Run, Endless, Co-op (revive) + Daily and Endless boards | #19 |
| 2D | Trophies (11 badges), ticket stubs, daily streak, trails / mannequin skins / playbills | #20 |
| 2E | Environment for Acts IV–VI: nervous lamps, swaying curtains, beams, lore | #21 |
| 2F | Coyote time, jump buffering, ledge forgiveness, touch camera | #22 |
| 2G | Cosmetic-only store for the new cosmetics; "only cosmetics for sale" test | #23 |
| 2H | Clip Mode, near-miss slow-mo replay, shareable ticket, photo spots | #24 |
| 3 | Hardening spec, budgets measured, screenshots of every stage | #25 |
| 4 | Launch checklist (IDs by file and line), store page, 10 Reel ideas, README, STATUS | #26 |

The PRs are **stacked**: merge them in order (#16 → #26). Each shows only its own diff once the one
before it is merged.

## Numbers

- 90 Luau modules (src), 30 test files. `scripts/check.sh`: StyLua, Selene (0 warnings), 60+ offline
  unit tests, Rojo build, and the Lune smoke suite (server sim + client sim) all pass.
- Studio (play mode): **3,961 parts** (budget 12,000), 99 lights, 12 emitters. Output clean apart
  from the expected placeholder / DataStore notices.
- `[Main] Don't Look Backstage ready: 6 stages`.

## What only you can do

1. **Publish the place once.** DataStores, the three boards and the daily streak need it.
2. **Fill in IDs**: 11 badges, 3 game passes, 4 developer products, 26 asset placeholders (audio).
   Exact lines are in [docs/LAUNCH_CHECKLIST.md](docs/LAUNCH_CHECKLIST.md).
3. Experience questionnaire, private servers, store page text and thumbnails (also in the checklist).

## Top things to playtest by hand

1. **Stage 4 light-rig beams**: is the timing fair on a phone? (`Layouts/Stage4.luau` → `movers`)
2. **The "Don't Look" rule on a phone**: does looking/freezing feel natural, and is the stare
   meter readable? (`Config.Mannequin.Look`)
3. **Stage 6 with the full cast**: too much for younger players? (`Config.Mannequin.UnderstudyDelaysByStage[6]`)

Everything else that couldn't be verified without eyes, hands or a live server is listed, with
where to tune it, in [docs/KNOWN_RISKS.md](docs/KNOWN_RISKS.md).
