# Status — Don't Look Backstage

_Phase 0 audit, 2026-11-22. Audited at the tip of the open PR stack (PR #13, `ccr-bb082184-1o0by9-e8-docs`),
which contains PRs #1–#13 in order._

## Summary

- **Code:** 72 Luau files (1 Script, 1 LocalScript, 70 ModuleScripts), about 12,500 lines. The "about 56"
  in the brief was the count after PR #3; the visual/environment PRs #4–#13 added the rest.
- **Checks (run locally on Windows with the CI-pinned tools):** StyLua clean, Selene 0 errors / 0 warnings,
  offline unit tests all pass, Rojo build OK, Lune smoke tests pass (~265 runtime checks across full runs,
  catches, DataStore outages, receipts, every UI screen, environment clearance and readability).
- **CI:** green on the head of every PR #1–#13.
- **GitHub:** `main` only holds the scaffold commit. All 13 PRs are still open and form one linear stack
  (#1 → #2 → … → #13), so merging in order is a series of fast-forwards.
- **Studio:** nothing has ever been playtested in Studio. Every risk in `docs/KNOWN_RISKS.md` is still open.
- **Earlier lore-props work** is PR #6 (E1, `LoreProps.luau`, `Lore.luau`, `Set/Story.luau`). It is in the stack and
  is not duplicated anywhere.

## Known bugs / issues found in this audit

| # | Issue | Impact | Fix |
| --- | --- | --- | --- |
| B1 | **Windows line endings break the format check.** Git for Windows defaults to `core.autocrlf=true`, so a fresh clone on a PC has CRLF files and `stylua --check` fails on every file. | `scripts/check.sh` fails on DZ's PC out of the box (CI on Linux is unaffected). | Add `.gitattributes` with `* text=auto eol=lf`. |
| B2 | **README shows mojibake** (`â€“`, `Â·`, `â˜…`) when read with a non-UTF-8 reader. The files themselves are valid UTF-8. | Cosmetic, only in some Windows tools. GitHub renders fine. | None needed; noted. |
| B3 | **Toolchain not installed on the PC** (no rokit, rojo, stylua, selene, lune, gh). | Can't run `rojo serve` or checks without it. | Installed the pinned binaries to `%USERPROFILE%\robloxtools` for this session. Rojo Studio plugin still to install. |
| B4 | `KNOWN_RISKS.md` part budget line says "about 370 parts" in one place and "3,203 parts" in another. | Docs inconsistency (370 was before PRs #4–#13). | Re-measure in Studio in Phase 1 and fix the docs. |

No logic bugs were found by the automated checks. The real bugs will show up in Studio (Phase 1).

## Untested in Studio (highest risk first)

1. Mannequin physics (unanchored rig on AlignPosition/AlignOrientation): sinking, jitter, lag.
2. Mannequin limb animation via `Motor6D.Transform`.
3. Stage 2 slide-mat wedge orientation (`Builders.slopeCFrame`).
4. Server teleports of client-owned characters (checkpoint/respawn snap-back).
5. Jump feel versus the 70% gap rule; difficulty at a 1.5 s delay on phones.
6. Rendering: transparent light shafts, rotated cylinders/wedges, SurfaceGui text, curtain pivot axis, density.
7. DataStores, badges and purchases (need API access on / a live server).
8. Mobile UI: safe areas, default jump button hiding, text scaling.
9. Part count and FPS on low-end phones.

## Module inventory

**DONE** = implemented and exercised by the smoke tests, but never run in Studio.
**PARTIAL** = exists but falls short of DZ's Phase 2 brief. Nothing in the current code is a stub.

### Shared (`src/shared`)

| Module | Status | Notes |
| --- | --- | --- |
| Config | DONE | All tunables. 3 stages; quality presets Low/Medium/High. |
| Theme | DONE | Central colours/materials/surfaces (already the "central Theme.luau" asked for in 2E). |
| Assets | DONE | 24 sound + 2 image placeholders (all `0`). |
| Types, Remotes, Signal, Clock, Zone, TimeFormat, JumpMath | DONE | Pure helpers, unit-tested. |
| Lore | DONE | Cast list with one name crossed out, playbills, kid-safe text tests. |
| MannequinRig | PARTIAL | Block rig with Motor6D joints. No pose copying, head tilt or reach (2A). |

### Server (`src/server`)

| Module | Status | Notes |
| --- | --- | --- |
| Main.server | DONE | Boot order; prints `Don't Look Backstage ready: 3 stages`. |
| MapBuilder/init, StageBuilder, Builders, LayoutTypes, LayoutValidator | DONE | Data-driven stages, 70% jump rule. |
| Layouts/Stage1–3 | DONE | Stages 4–6 MISSING (2B). |
| Lobby, LightingSetup, Dressing, Props, SetPieces | DONE | Moonlit teal, atmosphere, bloom, proscenium, seating, rigging. |
| Set/Auditorium, Street, CurtainCall, Story | DONE | Per-stage set dressing and story props. |
| LoreProps | DONE | Playbills, cast list, notice boards (earlier lore thread, PR #6). |
| Services/RoundService | DONE | Run state machine, zones, anti-cheat timing. Story mode only (2C). |
| Services/CheckpointService | DONE | Stage entrances as checkpoints. |
| Services/MannequinService, Mannequin/Mannequin, Mannequin/Trail | PARTIAL | Copycat delay + painted-door Shortcut + ambush done. Mirror, Understudy and the "Don't Look" stare rule MISSING (2A). |
| Services/ScareService | DONE | One scare per stage (3). |
| Services/AmbienceService | DONE | 5 layered 3D ambience loops + reverb per room. |
| Services/DataService, ProfileSchema, Retry | DONE | Versioned profiles, merge-safe UpdateAsync, BindToClose. No streak/daily reward fields (2D). |
| Services/LeaderboardService | PARTIAL | Global best story times. No Endless or Daily boards (2C). |
| Services/Badges | PARTIAL | 3 badges (First Escape, Opening Night, Spotted the Door). More achievements needed (2D). |
| Services/MonetizationService | DONE | Cosmetic passes/products, idempotent ProcessReceipt with recorded purchase IDs (2G covered; more items optional). |
| Services/RemoteGuard | DONE | Validation + rate limits on every remote. |
| Services/Analytics | DONE | Print sink with event catalogue. |

### Client (`src/client`)

| Module | Status | Notes |
| --- | --- | --- |
| Main.client, ClientState, Quality | DONE | Quality Auto/Low/Medium/High, Low on touch. |
| UI/UIRoot, Widgets, Hud, TitleCard, Captions, LobbyPanel, SettingsPanel | DONE | Reduced Scares toggle exists. No Clip Mode (2H) or mode picker (2C). |
| UI/FinishTicket | DONE | Theatre ticket. Not yet "shareable" (2H). |
| UI/Wardrobe | PARTIAL | Ticket skins only. No trails, mannequin skins, playbill backgrounds or trophy shelf (2D). |
| UI/DebugOverlay | DONE | Studio-only stats overlay. |
| Input/MobileJump | PARTIAL | Big jump button. No coyote time, jump buffering or ledge forgiveness (2F). |
| Camera/CameraEffects, Vignette | DONE | Shake/vignette respect Reduced Scares. |
| Audio/AudioController, AmbienceController, ProximityFX | DONE | Heartbeat rises with proximity. Silent until audio IDs are added. |
| World/MannequinAnimator | PARTIAL | Walk swing + bow. Pose copy / head tilt / reach MISSING (2A). |
| World/Scares, DoorEffects, Hazards, Curtains, Ambient, StageLight | DONE | Reactive floorboards, curtains, flickering lamps already exist (most of 2E). |

## Missing versus the Phase 2 brief

| Brief item | State |
| --- | --- |
| 2A Mannequin overhaul (pose copy, head tilt, reach, Mirror, Understudy, "Don't Look" stare rule) | MISSING (Copycat + Shortcut exist) |
| 2B Stages 4 The Flies, 5 The Prop Room, 6 Opening Night | MISSING |
| 2C Endless, Co-op (revive), Daily Run modes | MISSING (Story only, 3 stages) |
| 2D Trophy shelf, trails, mannequin skins, playbill backgrounds, more badges, daily reward, streak | MISSING (titles + ticket skins exist) |
| 2E Visual/environment upgrade | MOSTLY DONE via PRs #4–#13; needs Studio verification |
| 2F Coyote time, jump buffer, ledge forgiveness | MISSING (Reduced Scares exists) |
| 2G Monetization | DONE (extend with the new cosmetics) |
| 2H Clip Mode, near-miss slow-mo replay, shareable ticket, photo spots | MISSING |
| 3 Under 12k parts / quality setting / screenshots | Quality setting done; part count and screenshots need Studio |
| 4 Launch checklist, Reel ideas | Checklist exists, needs update; Reel ideas MISSING |
