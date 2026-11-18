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

## Environment risks (added by the visual/environment work)

These are the ones to look at first with [VISUAL_CHECKLIST.md](VISUAL_CHECKLIST.md) open.

| # | Risk | Why it could not be tested | What you would see | Where to fix |
| --- | --- | --- | --- | --- |
| E1 | **Transparent light volumes.** Moonlight shafts and the Act III beams are large faint Neon parts. Their look depends entirely on how Roblox blends them. | No renderer offline | Shafts look like solid milky slabs, or are invisible | `Theme.Surfaces.MoonShaft` / `WarmBeam` transparency; or set Graphics to Low, which removes them |
| E2 | **Overdraw on phones.** Those same volumes, the vignette and the particles all cost fill rate. | No device profiling | FPS drops looking down a shaft or at the two beams | Auto already picks **Low** on mobile (shafts off). Tune `Config.Quality.Levels` |
| E3 | **Cylinder and wedge orientation.** Beams, the painted moon, the door rose and the arch corners are rotated primitives. I verified the maths by hand, not by eye. | No renderer | A beam points sideways, the moon faces into the wall, an arch corner sits inverted | `SetPieces.narrowingBeam` / `paintedMoon` / `rightTriangle` |
| E4 | **SurfaceGui text layout.** Every lore board, the countdown and the step stencils are text drawn on part faces. Font metrics are a Roblox runtime thing. | No text renderer | Text clipped, overflowing, or too small to read | `LoreProps.luau` (board padding / `UITextSizeConstraint`), `Lore.luau` for shorter lines |
| E5 | **Which face is which on a step.** The cardboard step tape/stencils use Top/Left/Right faces; I outlined all four top edges so it reads whichever way the face maps. | No renderer | Tape or stencil on the wrong face | `Set/CurtainCall.luau` → `dressStep` |
| E6 | **Curtain pivot direction.** Strips sway about their top edge, choosing an axis from their shape. | No renderer | A curtain swings sideways, or rotates about its middle | `client/World/Curtains.luau` → `rollAxis` |
| E7 | **Density.** Seats, confetti and props are placed by a seeded random. The numbers look sensible but I have never seen them. | No renderer | Too sparse, or too busy to read the route | `Config.Map.VisualSeed` to reshuffle; counts in `Set/*.luau` |
| E8 | **Ambient sound mix.** Five layered loops plus room reverb. Levels and rolloff are judged by ear. | No audio, and all IDs are placeholders | A layer dominates, or the reverb sounds like a cave | `Config.Ambience.Layers` volumes, `Config.Ambience.Reverb` |
| E9 | **Chimney smoke near the ceiling.** Act II chimneys sit on the facade roofline, close to the room ceiling. | No renderer | Smoke visibly clips through the ceiling | Lower the chimneys in `Set/Street.luau` → `skyline` |
| E10 | **Reverb switching.** Each client retunes a shared SoundGroup locally. Correct by Roblox's rules, but untested live. | No audio engine | Reverb does not change between acts | `client/Audio/AmbienceController.luau` |

### What *was* proven about the environment, automatically

- **Nothing decorative blocks the route.** `clearance.spec` checks standing room above every
  walking lane, the flight path of every jump, and the openings of exits and doors. It caught
  nine real placement mistakes during this work.
- **The route stays visible.** `readability.spec` checks every platform is styled as a walkable
  surface and is measurably brighter than the set within 22 studs of it. Verified to fail when a
  platform is darkened, so it is not a rubber stamp.
- **Sound cannot bleed between rooms.** Every ambience layer falls silent before the next stage begins.
- **Budgets hold.** 3,203 parts of 12,000; 15–18 lights and 1–4 emitters per stage.
- **The story is consistent.** Acts match stage names, exactly one cast member is crossed out,
  every line is short enough to read at a glance, and the tone stays kid-safe.
- **Scares survive Low quality.** The Act II lamp death still happens on the cheapest setting.

---

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
