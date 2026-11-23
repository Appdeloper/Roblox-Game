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

## Verified in Roblox Studio (Phase 1, 2026-11-22)

Played in Studio 0.748 through its MCP server, with the repo scripts synced in. Runs were driven by moving
the character along each stage's route from a client script and reading the Output. Screenshots are in
[screenshots/](screenshots/).

| Check | Result |
| --- | --- |
| Boot and Output | Clean. `[Main] Don't Look Backstage ready: 3 stages`. Only expected notices (placeholders, DataStore unavailable). |
| Full run, stages 1 → 3 | Finished in 48.8 s with 0 retakes: `RunFinished`, finish ticket data, **Opening Night** title, best time. |
| Slide mat (stage 2) | Raycast on the live wedge: +5 studs at the −X end, −5 at the +X end, so it slopes **down toward the landing**. Risk 3 closed. |
| Mannequin trail-follower | Stays about 20–30 studs behind at running speed; standing still gets you caught in about 1.4 s. |
| Mannequin physics | Upright (UpVector.Y = 1.00), not sinking (root 0.3 studs below the player's), at rest when parked. Risk 1 mostly closed; jitter at speed not judged by eye yet. |
| Painted doors | `DoorWarning` (about 2.8 s) then `DoorOpened` in stages 1 and 3. |
| Catch / respawn | `Caught` → retake +1 → back at the stage entrance. The mannequin parks at its home spot and does **not** re-catch while you stand at the entrance (no catch loop). |
| Checkpoints | Each stage clear sends you to the next stage's entrance; a retake returns you to the current one. |
| Stage 3 exits | The fake exit gives `FakeExit`, the real one finishes the run. |
| Badges | `FirstEscape` and `OpeningNight` fire on finish (logged, since the IDs are placeholders). |
| Part count | 3,260 BaseParts and 57 lights, well under 12,000. |

**Not verified in Studio yet:** DataStore saving and the leaderboard (an unpublished place cannot use
DataStores, even with API access on: publish once, then retest), purchases, mobile emulator layout,
and the look of stages 2 and 3 (Studio closed before those screenshots were taken).

## Mannequin overhaul (Phase 2A): verified and open

Verified in Studio: looking at the mannequin freezes it (`Pose = Frozen`), the HUD stare meter fills,
at 2.2 s `StareLunge` fires and it closes in; the stage 2 Mirror appears and cracks before the slide
mat; stage 3 spawns two Understudies. Open, needs eyes and hands:

| Risk | What you'd see | Where to fix |
| --- | --- | --- |
| Head-follow axis on the block rig | The head turns away from you, or tilts instead of turning | `MannequinAnimator.lookAngles` (swap the sign of `yaw`) |
| Look cone on phones | Freezing feels too easy or too hard to trigger | `Config.Mannequin.Look.MaxAngleDegrees` |
| Mirror spacing | The reflection appears too late, or crowds the roofs | `Config.Mirrors[2]` (`From`, `Plane`), `Mirror.VanishGap` |
| Three chasers in stage 3 | Too punishing for younger players | `Config.Mannequin.UnderstudyDelays` (fewer or later) |

## Six stages (Phase 2B): verified and open

Verified in Studio: a full six-stage run finishes with the Output clean and prints
`ready: 6 stages`. A light-rig beam sends you back (`Spotted`), the stage 5 and 6 mirrors crack,
the finale's fake doors bump you and the real one finishes the run. 3,813 parts in all.

| Risk | What you'd see | Where to fix |
| --- | --- | --- |
| Light-rig timing | Beams feel unfair, or too easy to slip past | `Layouts/Stage4.luau` → `movers[*].motion` (`period`, `halfWidth`), `Config.Hazards.BeamLeniency` |
| Sandbag and shelves push you on the client | They don't push, or they fling you too hard | `client/World/Movers.luau` (`Solid` parts collide locally), mover `size`/`amplitude` |
| Conveyor speed | The belt doesn't carry you, or it's too strong for phones | `Layouts/Stage5.luau` → `Conveyor.conveyor` |
| Shrinking crates | The crate shrinks out from under you without warning | `Layouts/Stage5.luau` → `pulse.hold`, `pulse.min` |
| Audience readability | The house reads as clutter around the risers | `Set/Backstage.luau` → `openingNight` (rows, spacing) |
| Stage 6 difficulty | Four chasers plus a mirror is too much for younger players | `Config.Mannequin.UnderstudyDelaysByStage[6]` |

## Game modes (Phase 2C): verified and open

Verified in Studio: the lobby shows Daily Run, Endless and Co-op buttons. Each mode starts with
the right HUD pill (`☀ DAILY RUN · 1/4`, `∞ ENDLESS · stage 1 · ♥♥♥`, `👥 CO-OP · 1/6`). A solo
Co-op gathers for 10 s, then starts. The sim covers the rest: Daily first-finish-only, Endless
lives/score/speed-up, Co-op downed → revive → shared clear → party retake.

| Risk | Why it couldn't be tested | Where to fix |
| --- | --- | --- |
| Daily/Endless boards | DataStores need a published place | `LeaderboardService.refreshModes`; store names in `Config.Modes` |
| Co-op with real players | Needs 2+ clients (Studio **Test → Clients and Servers**) | `RoundService` co-op section; `Config.Modes.Coop` |
| Downed players | They stand still with WalkSpeed 0; there's no "downed" pose yet | `RoundService.setDowned` |
| Endless difficulty curve | Needs real players | `Config.Modes.Endless` (`DelayStep`, `MinDelay`, `Lives`) |

## Progression (Phase 2D): verified and open

Verified in Studio: the trophy shelf fills locally (22 parts for 11 trophies), and all five wardrobe
tabs exist. The sim covers stubs, trophies, unlocks, equipping, the Copycat skin and the streak.

| Risk | Why | Where to fix |
| --- | --- | --- |
| Badges | Placeholder IDs (0); BadgeService only awards in live servers | `Config.Badges` (8 new keys) |
| Streak across servers | Needs DataStores (published place) | `ProfileSchema.merge` (`LastDay`/`Streak`) |
| Trail look | Colour/lifetime judged without seeing it | `CosmeticsService.buildTrail` |
| Trophy shelf readability | Small cups; might be hard to see from the stage | `client/World/TrophyShelf.luau` sizes |

## Environment for Acts IV–VI (Phase 2E): verified and open

Acts IV–VI now have the same environment language as Acts I–III: nervous work lamps
(`FlickerLamp`, which flicker harder as your mannequin closes in), swaying drapes and house
curtains (`Curtain`), moonlight/warm beams with dust, and lore notices (the fly crew, the props
table, and the opening-night call sheet with the understudy line struck through). The clearance
and readability specs pass, and there are 3,890 parts.

**Not verified by eye:** Studio's screen capture returned a blank 3D view whenever the Studio
window wasn't in front, so stages 2–6 have no screenshots yet. Keep the Studio window visible and
take them with the Phase 3 screenshot pass, or by hand (see `docs/VISUAL_CHECKLIST.md`).

## Feel and fairness (Phase 2F): verified and open

Coyote time (0.12 s), jump buffering (0.15 s) and the one-jump rule are pure functions with unit
tests (`shared/JumpAssist.luau`). The client runs in Studio with a clean Output. Already in place
from earlier work: high-contrast walkable surfaces (readability spec), no decor on the route
(clearance spec), the big mobile jump button, and the Reduced Scares setting (no shake, no flashes).

| Needs hands-on testing | What you'd notice | Where to tune |
| --- | --- | --- |
| Coyote/buffer windows | Jumps feel floaty or too strict | `Config.Feel.CoyoteSeconds` / `BufferSeconds` |
| Ledge forgiveness | You pop up onto ledges you clearly missed, or it never helps | `Config.Feel.LedgeReach` / `LedgeLift` |
| Touch camera | Too close or too far on phones | `Config.Feel.TouchCamera` |

## Viral tools (Phase 2H): verified and open

Verified in Studio: six 📸 photo spots are built, and standing on the lobby one shows the
**Strike a pose** button. The client smoke spec covers Clip Mode (HUD hidden, ⏺ exit, everything
back). The near-miss replay, share and invite calls are wrapped in `pcall`.

| Needs hands-on testing | Why | Where to fix |
| --- | --- | --- |
| Near-miss replay framing | Camera orbit judged without seeing it | `client/World/NearMiss.luau` (`play`), `Config.Viral` |
| Share sheet | `CaptureService` prompts only appear on real devices | `client/UI/ClipMode.luau` → `snapshot` |
| Photo-spot camera angles | Picked from the layout, not by eye | `CameraOffset` in `Dressing.luau` / `Lobby.luau` |

## Quality and performance (Phase 3)

Measured in Studio (play mode, server view): **3,961 BaseParts** (budget 12,000), **99 lights**,
**12 particle emitters** for the whole place (lobby + six stages). Quality is Low/Medium/High
with **Auto = Low on touch devices** (`client/Quality.luau`, `Config.Quality`). Screenshots of the
lobby and every stage are in [screenshots/](screenshots/).

`tests/smoke/hardening.spec.luau` proves the following:
- Garbage into **every** client→server remote doesn't crash the server or change anything. That covers wrong types, extra arguments, NaN, infinity, 5,000-character strings, tables and Vector3s.
- You can't freeze another player's mannequin.
- Unknown modes are ignored.
- Spam is rate-limited.
- Dying mid-run keeps the run.
- An empty server holds no mannequins or loops.
- A rejoining player starts in the lobby.

Not yet checked on a real phone: frame rate on low-end devices and the Low preset's look.
Studio's Device Emulator (Test → Device) is the next step; Auto picks Low there.

## What is NOT verified, by priority

Check these first. Each one names the [FIRST_PLAYTEST](FIRST_PLAYTEST.md) step that exposes it.

| # | Risk | Why it couldn't be tested | What you'd see if wrong | Where to fix |
| --- | --- | --- | --- | --- |
| 1 | **Mannequin physics.** It uses an unanchored, server-owned rig pulled by rigid `AlignPosition`/`AlignOrientation`. | No physics engine outside Roblox | The mannequin sinks, jitters, spins, or lags well behind the 1.5 s replay (playtest steps 5–7) | `src/server/Services/Mannequin/Mannequin.luau` (`Mannequin.new`, `_apply`) |
| 2 | **Mannequin limb animation.** The client writes `Motor6D.Transform` every frame. | Rendering only | Limbs don't swing or the bow doesn't show; the mannequin glides stiffly (steps 5, 8). This is cosmetic: catching still works. | `src/client/World/MannequinAnimator.luau` |
| 3 | **Slide mat direction.** WedgePart rotated −90° mathematically aligns the thin edge (-Z) to world +X, sloping down from x=101 to x=125 toward the landing. | Verified mathematically in `Builders.slopeCFrame` and `Stage2.luau`. | Visually verified downward slope in layout. | `src/server/MapBuilder/Builders.luau` → `slopeCFrame` |
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
- `[Main] 26 asset placeholders still to replace`. There's no sound until you add audio IDs.
- `[MapBuilder] disabled stray SpawnLocation Workspace.SpawnLocation` when using the Baseplate template.
