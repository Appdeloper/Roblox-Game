# Architecture

## Principles

- **The server is authoritative.** It owns run state, retakes, timing, catches, rewards, data and
  purchases. Clients render, animate and send *requests*, and every request goes through
  `RemoteGuard`.
- **One source of truth for tunables.** `Config.luau` holds plain data and is unit-tested offline.
  Colours live in `Theme.luau` and asset IDs in `Assets.luau`.
- **Pure where possible.** Layouts, the layout validator, jump math, profile schema and merge, and
  time formatting have no engine dependencies, so they're tested without Roblox.
- **Mobile budget.** The server uses one Heartbeat (all mannequins) plus a 10 Hz zone loop. Clients
  poll hazards and proximity at about 15 Hz, curtains sway on looping tweens, and animation is
  skipped for distant mannequins. The map is about 370 parts with a handful of lights per room.

## Boot order (`src/server/Main.server.luau`)

```
Remotes.init()                 create every RemoteEvent before clients look for them
MapBuilder.build()             lobby + 3 stages + lighting → MapInfo (spawns, zones, door paths)
RemoteGuard.init()
DataService.init()             profiles load on PlayerAdded
MonetizationService.init()     ProcessReceipt, pass checks on ProfileLoaded
MannequinService.init()
CheckpointService.init(map)
RoundService.init(map)         players, characters, zone loop, start prompt
RoundService.setTicketEnricher(DataService.enrichTicket)
LeaderboardService.init(board, RoundService.RunFinished)
Badges.init(RoundService.RunFinished, MannequinService.DoorOutran, DataService.grantTitle)
ScareService.init()
```

Services talk through function calls in one direction, plus `Signal`s going back, so there are no
require cycles:

```
RoundService ──calls──▶ CheckpointService, MannequinService, Analytics, RemoteGuard
     │ signals: RunFinished, StageEntered, ScareZoneEntered
     ▼
ScareService, LeaderboardService, Badges, DataService (via ticket enricher)
MannequinService ──signals──▶ Caught, DoorOutran (RoundService, Badges listen)
```

## Run state machine (RoundService)

```
Lobby ──(stage-door prompt / RequestStart)──▶ Running(stage 1)
Running(n) ──exit zone──▶ Running(n+1) … Running(3) ──real exit──▶ Finished ──▶ (Encore) Running(1)
Running ──(caught | fell | died)──▶ respawning ──RespawnDelay──▶ same stage entrance (retake +1)
Running ──(Leave button | disconnect)──▶ Lobby          (analytics: quit_stage)
```

Each running player is checked every `Config.Zones.CheckInterval` (0.1 s) for:

- falling below the kill line
- painted-door triggers
- the stage's scare zone (once per run)
- the stage exit
- the left/right exits in stage 3, where one is real (picked at random per run) and the other gives
  a "fake exit" bump

A clear faster than `Config.AntiCheat.MinStageSeconds` marks the run unverified. An unverified run
still finishes, but gets no leaderboard entry and no badges.

## The mannequin (`Services/Mannequin/Mannequin.luau`)

Each player has their own mannequin, built server-side from `MannequinRig`. Its root is unanchored
and server-owned. Rigid `AlignPosition`/`AlignOrientation` constraints pull it to a target, so
clients see smooth, interpolated physics replication. Every part has `CanCollide`, `CanTouch` and
`CanQuery` off.

| State | Behaviour |
| --- | --- |
| **Idle** | Stands at the stage's home spot until the player is `StartMoveDistance` from the entrance (no catches while you read the title card). |
| **Warmup** | Records the player's yaw-only CFrame at 20 Hz. Waits until a full `Delay` (1.5 s) of history exists. |
| **Trailing** | Replays the trail at time `now − Delay`, blending out of its home spot over `EmergeSeconds`. It catches up at `CatchUpRate` after a scare freeze, and drifts back at `DriftBackRate` if a shortcut left it closer. |
| **Shortcut** | Painted door: *Approach* (glides to the entry door) → *Path* (hidden waypoints behind the scenery) → *Hold* (until `MinWarningSeconds` of warning have passed) → *StepOut* (door opens). |
| **Ambush** | At the exit step: it rejoins the trail at the sample where the player passed the door, but never closer than `MinRejoinDelay`. If the player never comes, it falls back to normal trailing after `AmbushSeconds`. |

**Catching** happens when the horizontal distance is under `Catch.Distance` and the vertical
difference is under `VerticalTolerance`. It's disabled during:

- the respawn grace period (`GraceSeconds`)
- scare holds
- the emerge blend
- the hidden phases of a shortcut

**Door telegraph.** On trigger, the server sends `DoorWarning(doorId, seconds)` to the owner only.
That player's client turns the exit door's handle, lights the strip under it and plays a creak.
`DoorOpened` swings the door open. If the trail shows the player had already passed the exit step
when the door opened, the server sends `DoorOutran`, which awards the *Spotted the Door* badge and
the *Door Spotter* title.

## Map (`MapBuilder/`)

- `Layouts/StageN.luau`: pure data in stage-local coordinates. It lists the route (each element has
  a `link`: Jump / Walk / Climb / Drop / Slide), trusses, solids (walls with optional window holes),
  door pairs and their hidden path, zones, backdrop, exits and the window-walk marker.
- `LayoutValidator`: enforces the **70% rule**. Every jump gap must be under
  `MaxGapRatio × maxJump` for its rise (projectile math in `JumpMath`). Rises must stay under 70%
  of max jump height, climbs need a touching truss, surfaces must sit above the kill line, door
  triggers must sit on the route and exits on a surface. It warns in Studio and fails CI.
- `StageBuilder` builds the room shell, safety net plus fog, route, trusses, solids and doors, then
  tags everything interactive and stamps it with `Stage`. `Dressing` adds per-stage props and
  lights. `Lobby` builds the rehearsal room, spawn, ghost light, chalkboard leaderboard, stage door
  prompt and wardrobe.
- Clients find interactive pieces by **CollectionService tag**: `PaintedDoor`, `StageExitDoor`,
  `Backdrop`, `CollapseStep`, `ShadowScreen`, `WindowWalk`, `Curtain`, `AudienceSeat`,
  `WardrobePrompt`, `Mannequin`.

## Client (`src/client`)

`Main.client.luau` initialises the controllers and wires every server→client remote in one
readable place.

- **UI**:
  - `UIRoot`: three ScreenGuis (Hud and Modal respect the safe area; Overlay is full screen), with
    a UIScale based on a 720 px short side
  - `Hud`, `TitleCard`, `Captions` (with Skip), `SettingsPanel` (Reduced Scares, Leave),
    `LobbyPanel`, `FinishTicket` (5 skins), `Wardrobe`
- **Input**: `MobileJump` is a 150 px labelled jump button that hides the default one.
- **World**:
  - `MannequinAnimator`: procedural Motor6D.Transform walk, idle tilt and bow, and fades other
    players' mannequins
  - `DoorEffects`
  - `Hazards`: the backdrop, collapsing steps and real/fake exits, all simulated locally for
    per-player fairness
  - `Scares`
  - `Curtains`
- **Camera/Audio**:
  - `CameraEffects`: fade, flash and shake. Flash and shake are disabled in Reduced Scares.
  - `AudioController`: placeholder-safe sound playback
  - `ProximityFX`: heartbeat, creak and the edge pulse

## Remotes (`shared/Remotes.luau`)

| Server → client | Client → server (validated + rate limited) |
| --- | --- |
| ProfileUpdated, RunStarted, StageStarted, Caught, Fell, DoorWarning, DoorOpened, DoorOutran, Scare, FakeExit, RunFinished, ReturnedToLobby, Notify | RequestStart `()`, RequestLobby `()`, SetSetting `(string, boolean)` (whitelisted key), EquipSkin `(string)` (must be owned), SetTrailEnabled `(boolean)` (must own the pass), ScareSkipped `(number)` (analytics only) |

`RemoteGuard` checks three things before a handler runs:

1. a token-bucket rate limit (`Config.Remotes`)
2. the exact argument count and types, with NaN, infinity and long strings rejected
3. that the handler runs inside a `pcall`

## Data (`DataService` + `ProfileSchema`)

- Key `player_<UserId>` in `PlayerProfiles`. Profiles are versioned (`SchemaVersion = 2`; v1
  profiles migrate).
- **Load**: `GetAsync` with retries and exponential backoff. If the load fails, or the stored data
  is from a newer schema, the session is `loadFailed`. Nothing is ever written, so a bad load can't
  overwrite a good profile, and the player is told saving is paused.
- **Save**: `UpdateAsync` merges onto what is stored *now*:
  - best time: the lowest wins
  - titles, skins and receipts: union
  - counters: stored value plus this session's unsaved delta
  - settings and equipped items: the latest value wins

  Saves are coalesced per player, run every 120 s as an autosave, on leave, and on `BindToClose`
  (with a timeout).
- **Purchases**: `ProcessReceipt` grants a product, records its `PurchaseId`, and answers
  `PurchaseGranted` only after the save succeeds. If Roblox retries, the grant is skipped and only
  the save is retried.

## Testing infrastructure

- `tests/run.luau` runs on the plain Luau CLI: Config sanity, JumpMath, TimeFormat, Signal and
  layout fairness.
- `tests/smoke/` runs on Lune and executes the real modules from the Rojo-built place:
  - `harness.luau`: a ModuleScript loader, a fake-clock `task` scheduler, and stubs for services
    Lune doesn't implement (in-memory DataStores with fault injection, BadgeService,
    MarketplaceService)
  - `sim.luau`: boots the real `Main.server.luau` with fake players, characters and logged remotes
  - `client.luau`: an Instance membrane that gives Lune instances events while keeping real
    property validation, then boots the real client `Main`

The specs cover:

- full escapes, catch, fall and death
- the fake exit
- two players
- leaving mid-chase
- bad and spammed remotes
- data merge and lockout
- leaderboard and badges
- receipts
- every UI screen
