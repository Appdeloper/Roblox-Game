# Known risks (things I couldn't verify without Studio)

## What *was* verified

Every push runs CI. Locally I also checked every API call against the current Roblox API dump.

- **Lint and format:** Selene with the full Roblox standard library (catches wrong `Enum` items,
  unknown globals and deprecated APIs), plus StyLua.
- **Layout fairness:** offline tests check every stage layout against the 70% jump rule.
- **Rojo build:** `rojo build` succeeds, and the instance tree matches `default.project.json`
  (1 Script, 1 LocalScript, 56 ModuleScripts in the expected places).
- **Runtime smoke tests (Lune):** the real server `Main` and client `Main` run from the built
  place.
  - Every ModuleScript gets required, so every `require` path resolves.
  - Every property write is validated against Roblox's reflection data.
  - Full runs are simulated: escape, catch, fall, death, fake exit, two players, disconnects,
    bad remotes, DataStore outages and merges, purchase retries, and every UI screen.

## What is NOT verified, by priority

Check these first. Each one names the [FIRST_PLAYTEST](FIRST_PLAYTEST.md) step that exposes it.

| # | Risk | Why it couldn't be tested | What you'd see if wrong | Where to fix |
| --- | --- | --- | --- | --- |
| 1 | **Mannequin physics.** It uses an unanchored, server-owned rig pulled by rigid `AlignPosition`/`AlignOrientation`. | No physics engine outside Roblox | The mannequin sinks, jitters, spins, or lags well behind the 1.5 s replay (playtest steps 5–7) | `src/server/Services/Mannequin/Mannequin.luau` (`Mannequin.new`, `_apply`) |
| 2 | **Mannequin limb animation.** The client writes `Motor6D.Transform` every frame. | Rendering only | Limbs don't swing or the bow doesn't show; the mannequin glides stiffly (steps 5, 8). This is cosmetic: catching still works. | `src/client/World/MannequinAnimator.luau` |
| 3 | **Slide mat direction.** A WedgePart rotated −90° should slope down toward the landing. | Geometry wasn't checked visually | You land at the bottom and face an icy ramp upward (step 9) | `src/server/MapBuilder/Builders.luau` → `slopeCFrame` (swap `-90` and `90` for `"+X"`) |
| 4 | **Jump feel.** The gaps are mathematically under 70% of max jump, but real Humanoid physics and mobile latency differ. | No Humanoid simulation | Jumps feel too hard or too easy (step 6) | `src/server/MapBuilder/Layouts/Stage*.luau`. The tests will tell you if an edit breaks the 70% rule. |
| 5 | **Difficulty.** At a 1.5 s delay, hesitating about 1.3 s on a ledge gets you caught. | Needs real players | Too punishing for younger players on phones | `src/shared/Config.luau`: `Catch.Distance`, `Catch.GraceSeconds`, `Door.*` |
| 6 | **Server teleports.** `Model:PivotTo` is called on client-owned characters for checkpoints and stage changes. | Network ownership isn't simulated | You snap back after a teleport, or the respawn takes a moment | `src/server/Services/CheckpointService.luau` → `teleport` |
| 7 | **Hiding the default jump button.** The game looks for `PlayerGui.TouchGui.TouchControlFrame.JumpButton`. | Roblox's touch UI isn't available offline | Two jump buttons on mobile (harmless) | `src/client/Input/MobileJump.luau` → `hideDefaultJump` |
| 8 | **UI layout on real screens:** safe areas, text scaling, overlap with the thumbstick | No renderer | Clipped text, or a button under the notch (step 10) | `src/client/UI/*` (sizes are in px at a 720 px reference, scaled by `UIRoot`) |
| 9 | **Rojo setting `Workspace.StreamingEnabled = false` and `Lighting.Technology = ShadowMap`** on your place | Rojo plugin behaviour | If streaming stays on, doors or stairs far away may not animate until you get close | Select **Workspace** in Studio → Properties → untick **StreamingEnabled** |
| 10 | **Real DataStores, badges and purchases** | These need a published place and live servers | Saving or purchase problems show as `[Retry]` / `[DataService]` warnings in Output | Turn on API access (PC_SYNC_GUIDE step 6). Test badges in a live server. |
| 11 | **Luau type-checker warnings.** Files use `--!strict`, but the full type checker couldn't run here (only lint and runtime tests). | Tool unavailable in this environment | Possible orange/blue underlines in Studio's Script Analysis. They don't stop the game. | Ignore, or tell me which lines and I'll tidy them |
| 12 | **Performance on low-end phones.** About 370 parts, about 7 lights per room, and dust particles. | No device profiling | FPS below 60 on old phones | `Config.Effects.DustRate`, lights in `src/server/MapBuilder/Dressing.luau` |

## Expected (not bugs)

- With API access **off**, Output shows `[Retry] load … failed` and `[Retry] leaderboard read failed`
  every minute, and you see "saving is paused this visit". Turn API access on to stop them.
- `[Badges] '…' earned but its badge ID is a placeholder` until you add badge IDs.
- `[Main] 18 asset placeholders still to replace`. There's no sound until you add audio IDs.
- `[MapBuilder] disabled stray SpawnLocation Workspace.SpawnLocation` when using the Baseplate template.
