# Don't Look Backstage — Build Plan

A haunted school-theatre parkour escape for Roblox (ages 9–17, mobile-first).
Everything — map, rig, UI, data — is generated from Luau in this repo and synced with Rojo.

## Ground rules

- Server is authoritative. Clients only render, animate and send *requests*. Every remote is validated + rate-limited.
- All tunables live in `src/shared/Config.luau` (numbers/strings only, so it is unit-testable outside Roblox).
  Colours/fonts live in `src/shared/Theme.luau`. Asset IDs live in `src/shared/Assets.luau` (placeholders = `0`).
- Mobile first: big touch targets, safe-area insets, one shared Heartbeat for mannequins, 10 Hz zone checks.
- Tone: spooky-fun. No gore, no jump-scare flashes in Reduced Scares mode, every scare has a caption.

## Milestones

- [x] **M0 — Scaffold & tooling**: `default.project.json`, `rokit.toml`, `selene.toml`, `stylua.toml`, `.gitignore`, CI workflow.
- [x] **M1 — Shared foundation**: `Config`, `Types`, `Theme`, `Assets`, `Remotes`, `Signal`, `JumpMath`, `TimeFormat`, `Zone`.
- [x] **M2 — MapBuilder**: lobby (rehearsal stage + leaderboard wall), Stage 1 Auditorium, Stage 2 Painted Street,
      Stage 3 Curtain Call. Data-driven layouts, jump-gap validation (< 70 % of max jump), spawns, kill nets,
      TrussPart ladders, slide mat, descending backdrop, collapsing staircase, two exits. Offline layout tests.
- [x] **M3 — MannequinService**: block rig with blank face, 20 Hz trail recorder + delayed replay, painted-door
      shortcut (warning → preset path → rejoin/ambush), catch detection, respawn grace, one mannequin per player.
- [x] **M4 — CheckpointService + RoundService**: stage entrances as checkpoints, retakes, run state machine,
      10 Hz zone watcher (exits, doors, scares, kill nets), analytics wrapper.
- [ ] **M5 — Scares**: shadow bow (S1), mannequin in the upstairs window + turning handle (S2), knock + applause (S3).
      Telegraphed, captioned, once per run, skippable, catch paused while they play.
- [ ] **M6 — Client UI**: title cards, retake counter, timer, big jump button, theatre-ticket finish screen,
      Reduced Scares toggle, lobby panel. All built in code with tweens.
- [ ] **M7 — DataService**: versioned profiles, UpdateAsync merge-saves, retries with backoff, failed-load lockout,
      autosave + BindToClose.
- [ ] **M8 — Leaderboard**: OrderedDataStore of best times + lobby SurfaceGui board.
- [ ] **M9 — Badges**: First Escape, Opening Night, Spotted the Door (placeholder IDs in Config).
- [x] **M10 — Monetization**: cosmetic gamepasses + dev products, idempotent ProcessReceipt with recorded purchase IDs.
- [x] **M11 — Analytics**: stage_started, stage_cleared, caught, quit_stage, finished (print sink).
- [x] **M12 — Polish**: moonlit teal lighting + warm spots, footlights, dust, curtain sway, creaks, proximity heartbeat.
- [x] **M13 — Docs**: README, ARCHITECTURE, TESTING (Studio + 2 Players + mobile emulator), LAUNCH_CHECKLIST.

Each milestone ends with: `stylua --check`, `selene`, `luau tests/run.luau`, `rojo build`, then a commit.

## Verification available in this repo (no Studio)

| Check | Command |
| --- | --- |
| Format | `stylua --check src tests` |
| Lint (Roblox std) | `selene src tests` |
| Pure-Luau unit tests (config, jump math, layouts) | `luau tests/run.luau` |
| Project builds | `rojo build default.project.json -o build/DontLookBackstage.rbxl` |

Everything else (physics feel, UI on devices, DataStores, purchases) is covered by `docs/TESTING.md`.
