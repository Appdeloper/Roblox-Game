# Don't Look Backstage

A spooky-fun parkour escape through a haunted school theatre, for Roblox (ages 9–17, mobile first).

You wake up on a rehearsal stage. Step through the **STAGE DOOR** and escape six stages while a
wooden mannequin copies your every move **1.5 seconds late**. Stand still and it catches up. Pass a
**painted door** (purple, with a brass ★) and the mannequin takes a shortcut through the scenery.
Watch for the handle turning and the light under the door. Get caught and it's "CUT! Take it from
the top": back to the stage entrance, plus one retake.

| Stage | What you do | Scare |
| --- | --- | --- |
| **1 · The Empty Auditorium** | Hop tipped-over seat rows, climb prop trunks onto the stage | Your shadow takes a bow… then the mannequin finishes it behind you |
| **2 · The Painted Street** | Climb the scenery ladder, cross four shop roofs, drop onto the slide mat, slip under the descending backdrop | The mannequin walks past the upstairs windows; a brass handle by the landing starts turning |
| **3 · Curtain Call** | Run down a collapsing cardboard staircase to two exits: one painted, one real (light beneath it) | One polite knock… then applause from the empty seats |
| **4 · The Flies** | Cross narrow catwalks high above the stage while rotating light rigs sweep them, dodge a swinging sandbag, climb the rope ladder | A light rig drops on its chain and its spot finds you |
| **5 · The Prop Room** | Jump crates that shrink and grow, run a conveyor belt of costumes going the wrong way, slip past sliding shelves | Every costume on the rail turns to look at you |
| **6 · Opening Night** | The whole cast chases you across a collapsing set to five exit doors. One is real | House lights up: the audience is all mannequins, and they stand |

### Game modes

| Mode | How it plays | Board |
| --- | --- | --- |
| **Story** | The six stages in order (START THE SHOW, or walk through the stage door) | ★ Best Escapes (fastest time) |
| **☀ Daily Run** | Four stages picked by the date, the same for every player that day, always ending on Opening Night. Only your first finish each day counts | Today's Daily Run (fastest first finish) |
| **∞ Endless** | Stages come shuffled and never stop. The mannequin gets a little faster every stage. 3 lives | Endless (most stages cleared) |
| **👥 Co-op** | Story for up to 4 friends. Tap Co-op within 10 s of each other. A clear moves everyone on; a caught player is *downed* until a teammate stands next to them for 1.5 s; if everyone's down, the cast takes it from the top | — |

### Progression (all cosmetic)

- **Trophies** (11) on your own trophy shelf in the lobby, each also a Roblox badge: First Escape,
  Opening Night, Spotted the Door, Stare Down, Mirror Mirror, Full House, Daily Double, Daily
  Devotee, Long Run, Cast Party, Revival.
- **Ticket book**: a stub for every act cleared and every mode finished.
- **Daily visits**: come back on consecutive days to build a streak (days 2, 3 and 7 unlock
  wardrobe items).
- **Wardrobe** tabs: ticket skins, trails, mannequin skins (your Copycat's wood), playbill
  backgrounds (the stage title cards), and your Collection.

At the end you get a **theatre ticket** with your escape time and retakes. Zero retakes earns the
title **Opening Night**.

Everything is built from Luau in this repo: the map, the mannequin rig, the UI and the lighting.
There's no hand-made `.rbxl` to keep in sync.

> **New to Rojo, or setting up from scratch on a PC?** Follow
> **[docs/PC_SYNC_GUIDE.md](docs/PC_SYNC_GUIDE.md)** (step by step), then
> **[docs/FIRST_PLAYTEST.md](docs/FIRST_PLAYTEST.md)**, and check
> **[docs/KNOWN_RISKS.md](docs/KNOWN_RISKS.md)** for what to verify first.

---

## Quick start

### 1. Install the toolchain

The repo pins its tools in [`rokit.toml`](rokit.toml): Rojo, Selene, StyLua and Lune.

```bash
# macOS / Linux (see https://github.com/rojo-rbx/rokit for Windows)
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
rokit install          # run inside the repo
```

Aftman users can copy `rokit.toml` to `aftman.toml` (same format) and run `aftman install`.

### 2. Install the Rojo Studio plugin

```bash
rojo plugin install
```

You can also install **Rojo** by *rojo-rbx* from the Creator Store, inside Studio.

### 3. Build the place and open it

```bash
rojo build default.project.json -o DontLookBackstage.rbxl
```

Open `DontLookBackstage.rbxl` in Roblox Studio, or start from Studio's **Baseplate** template;
both work. The map is built 400 studs up, so template parts never get in the way. MapBuilder
also switches off the template's SpawnLocation and its post-effects at runtime.

### 4. Live-sync with `rojo serve`

```bash
rojo serve
```

In Studio, open **Plugins → Rojo → Connect** (default `localhost:34872`). Code edits now sync into
Studio live. Press **Play**: the server builds the whole map on boot. Watch Output for
`[Main] Don't Look Backstage ready: 6 stages`.

### 5. Run the checks (same as CI)

```bash
scripts/check.sh
```

This runs StyLua (format check), Selene (Roblox-aware lint), the offline Luau unit tests, a Rojo
build, and the Lune runtime smoke tests. The smoke tests run the real server and client modules
through full games. See [docs/TESTING.md](docs/TESTING.md).

---

## Publishing

1. In Studio: **File → Publish to Roblox** (or **Publish to Roblox As…** the first time).
2. **Game Settings → Security**: turn on **Enable Studio Access to API Services** so DataStores
   (profiles, leaderboard) work in Studio. Without it the game still runs, but saving is paused and
   players are told so.
3. **Game Settings → Avatar**: R15 or R6 both work, since the mannequin and physics don't depend on
   the rig type.
4. Fill in the **Experience Questionnaire** on the Creator Dashboard. This game has mild,
   non-violent fear themes with no blood or gore.
5. Replace the placeholders below, then work through [docs/LAUNCH_CHECKLIST.md](docs/LAUNCH_CHECKLIST.md).

Later updates: `rojo build` or `rojo serve` into the published place, then publish again from Studio.

---

## Placeholders you must replace

Every placeholder is `0`. While an ID is `0` the related feature degrades gracefully: the game
stays silent, badges are logged instead of awarded, and shop items say "isn't on sale yet". In
Studio, the server prints how many asset placeholders remain.

| What | Where | How to get the ID |
| --- | --- | --- |
| 24 sound effects — 19 one-shots/loops (heartbeat, creaks, doors, knock, applause, stings) plus 5 looping 3D ambience layers (drip, wind, timber, piano, far applause) | `src/shared/Assets.luau` → `Assets.Sounds.*.Id` | Upload your own audio, or use free Creator Store audio you're licensed to use. Creator Dashboard → Development Items → Audio |
| Dust particle texture, vignette image (optional) | `src/shared/Assets.luau` → `Assets.Images.*.Id` | Upload a decal/image (built-in fallbacks are used while `0`) |
| Badges: First Escape, Opening Night, Spotted the Door, + 8 trophy badges (Stare Down … Revival) | `src/shared/Config.luau` → `Config.Badges` | Creator Dashboard → your experience → Engagement → Badges → Create |
| Game passes: Spotlight Trail, Velvet Curtain Border, Playbill Collection | `Config.Monetization.GamePasses.*.Id` | Creator Dashboard → Monetization → Passes |
| Developer products: Golden / Moonlit Ticket Skin, Sparkler Trail, Marble Mannequin | `Config.Monetization.Products.*.Id` | Creator Dashboard → Monetization → Developer Products |

Prices, names and icons are set on the Creator Dashboard. The display names in `Config` are only
used in-game.

---

## Repository layout

```
default.project.json     Rojo mapping (src/server → ServerScriptService, etc.)
src/shared/              → ReplicatedStorage.Shared
  Config.luau            every gameplay tunable (pure data, unit-tested)
  Theme.luau             colours & fonts      Assets.luau   asset IDs (placeholders)
  Types.luau Remotes.luau Signal.luau Clock.luau Zone.luau JumpMath.luau TimeFormat.luau
  MannequinRig.luau      block-rig mannequin builder (server chasers + client puppet)
src/server/              → ServerScriptService
  Main.server.luau       boot order / composition root
  MapBuilder/            procedural map: Layouts/StageN.luau (data), StageBuilder, Dressing,
                         Props, Lobby, LightingSetup, LayoutValidator (70% jump rule)
  Services/              RoundService, MannequinService (+ Mannequin/, Trail), CheckpointService,
                         ScareService, DataService (+ ProfileSchema), LeaderboardService, Badges,
                         MonetizationService, RemoteGuard, Analytics, Retry
src/client/              → StarterPlayerScripts.Client
  Main.client.luau       wires remotes → controllers
  UI/ Input/ Camera/ Audio/ World/   HUD, ticket, wardrobe, jump button, scares, hazards, FX
tests/                   offline Luau unit tests + Lune smoke tests (tests/smoke)
docs/                    ARCHITECTURE, TESTING, LAUNCH_CHECKLIST
.github/workflows/ci.yml format + lint + tests + build + smoke on every push
```

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the code fits together, and
[docs/ENVIRONMENT.md](docs/ENVIRONMENT.md) for how the world is built and what it is trying to say.

---

## Tuning

Everything lives in `src/shared/Config.luau`: mannequin delay and catch distance, grace period,
door warning time, scare timings, hazard speeds, stage text, data, leaderboard and UI sizes.
Stage geometry lives in `src/server/MapBuilder/Layouts/StageN.luau`. If an edit makes a jump unfair
(gap ≥ 70% of the max jump), `luau tests/run.luau` fails and Studio prints a warning.

---

## Known limitations

- **Not playtested in Studio by the author.** All logic is exercised by the Lune smoke tests:
  full runs, catches, DataStore merges, receipts, and every UI screen. Physics feel, camera,
  readability on real phones and audio balance still need hands-on testing. Start with
  [docs/TESTING.md](docs/TESTING.md).
- **No audio until you add IDs.** Every sound is a placeholder. Captions carry every important cue,
  so the game is still fully playable muted.
- **The mannequin is a ghost.** It glides through walls. That's by design, since it's what makes
  painted-door shortcuts work, and it never collides with players.
- **Hazards are local.** The backdrop, collapsing steps and door animations run on each player's
  own client, so other players won't see your stairs collapse. This keeps multiplayer fair.
- **Movement is trusted the way Roblox normally does it.** Character physics belongs to the
  client. The server validates stage order and enforces minimum stage and run times
  (`Config.AntiCheat`). Implausible runs still finish but stay off the leaderboard and earn no
  badges. There's no full movement anti-cheat.
- **Leaderboard names are usernames**, resolved and cached server-side. Display names aren't stored.
- **Badges can't be awarded in Studio.** Roblox only awards them in live servers. In Studio the
  server logs the award.
- `Lighting.Technology` is set to **ShadowMap** in `default.project.json` because it can't be
  scripted. Change it there if you want Future lighting on high-end devices.
- `Workspace.StreamingEnabled` is **off**. The whole map is about 370 parts, which is small, and
  clients find doors and hazards by tag.
