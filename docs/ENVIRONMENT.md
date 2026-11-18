# The environment

How the theatre is built, what it is trying to say, and the rules everything in it follows.

Everything here is generated from Luau at server start. There is no `.rbxl` to maintain, no
uploaded models and no paid assets. Change a number in `Theme.luau` or `Config.luau` and the
whole building changes with it.

---

## The story the building tells

A school drama club was rehearsing a play called **"The Understudy"**. The lead stopped coming.
A wooden rehearsal mannequin named **PINE** was marked in to cover. The dress rehearsal never
ended, and the countdown to opening night has run out.

Nobody says any of this. You read it off the walls:

| Prop | Where | What it tells you |
| --- | --- | --- |
| Playbill | Lobby back wall, Act II facade | The play's name, and its three acts — which are the three stages |
| Cast list | Lobby, and again by the two doors in Act III | `LEAD … R. HOLLOWAY` crossed out; `UNDERSTUDY … PINE` in red |
| Countdown board | Lobby right wall | `DAYS UNTIL OPENING NIGHT: 0`, with 5–1 rubbed out beneath |
| Costume tags | Lobby wardrobe rail | Four tags; the last reads `UNDERSTUDY · PINE` |
| Rehearsal schedule | Act I house wall | Every day struck off except `FRI 6:00 DRESS REHEARSAL — please do not leave the stage` |
| Script pages | Scattered in the seats, on decks, on the stage | `ACT III — two doors. only one is real.` · `(the understudy does not speak)` |
| Prompt book | Act III, in the wings | `CUE 31 — knock`, `CUE 32 — applause`, `CUE 33 —` and then nothing |
| Wet paint notice | Act II flats | "the moon is not dry yet" — the set was never finished |

All of the words live in **`src/shared/Lore.luau`**. Reword anything there and it updates
everywhere. `tests/lore.spec.luau` keeps the story internally consistent: the acts must match
the stage names, exactly one cast member may be crossed out, the mannequin must be named in
both the cast list and a tag, every line must be short enough to read at a glance, and the tone
must stay kid-safe.

### Props that teach instead of telling

- **Scuff marks** dragged along the floor toward every brass-star door — something heavy keeps
  going that way. They get longer and darker closer to the door.
- **Footprints** through the dust on the Act I stage, walking out through the backstage arch.
- **Glow bands** at the foot and head of the scenery ladder: climb here, get off here.
- The **brass star** has its own polished surface so it catches the light more than ordinary brass.

---

## Stage by stage

Each act has its own colour, light and shape so a clip is instantly placeable.

### Lobby — The Rehearsal Room
Small, warm and safe. A ghost light burns on the bare rehearsal stage, a chalkboard lists the
best escape times, and the wardrobe rail carries the costume tags. The whole premise is readable
before you ever press start.

### Act I — The Empty Auditorium
**Cold and teal.** The biggest room, and the only one with real depth.

- Curved rows of velvet seats sweep away into the mist below the route — some tipped up, a third
  faded and dusty, so no two rows look alike
- Torn aisle runners in separate worn pieces
- A back balcony, four opera boxes, gilded wall panels with gold rails
- A proscenium arch with fluted pillars, gathered curtains, a valance and a brass star crest
- A plank stage floor with per-plank shade variation, and a fly loft of battens, pulleys and ropes
- **Three high windows throwing shafts of moonlight** down into the seats, with dust drifting in them
- **One empty front-row seat**, picked out by a narrow warm spot

### Act II — The Painted Street
**Warm windows on an indigo night.** Flat, graphic, deliberately fake.

- Painted scenery shopfronts with framed windows, striped awnings and roof cornices
- Glowing painted windows on two floors; two of them cast real light
- **A painted moon** on the flats, with ring and craters
- **Chimneys smoking** along the facade roofline — never on the roofs you run across
- Wall lanterns, hanging backdrop cloths, and a fly rig over the audience side

### Act III — Curtain Call
**Cold cardboard, two warm doors.** Everything funnels to one choice.

- Cardboard steps dressed with packing tape and stencils (`FRAGILE`, `THIS SIDE UP ↑`) — the
  dressing is drawn on the step itself, so it falls *with* the step
- Curved rows of empty audience seats below, which bounce during the applause
- A proscenium arch, a plank stage, and a fly rig
- **Two beams narrowing toward the two exits** — the whole act in one image
- **Confetti and torn paper** settled on the stage and in the pit, for a curtain call that never happened

---

## Lighting rules

Light carries information here, not just mood.

| Rule | How it is done |
| --- | --- |
| **The safe route is the lit route** | A warm lamp hangs high over every landing and over the first and last step of each stage |
| **Danger is cold and unlit** | Teal fill far below the route, under the fog, marks the drop |
| **A door warning is impossible to miss** | The handle turns, a strip lights under the door, a pool of warm light widens across the floor, and the hinge creaks |
| **The real exit has light beneath it; the painted one does not** | Decided per run; the fake also gets a flat painted-on look |
| **Scares are telegraphed** | The caption is on screen *before* the lighting beat: a lamp dies in Act II, spotlights snap onto both doors in Act III |
| **Nothing is aimed at the camera** | Scare spotlights always point at the set |
| **Reduced Scares softens, never removes** | Snaps become fades; captions stay |

The overall mood comes from `Theme.Lighting`: a teal ambient so every shadow leans cold, light
moonlit fog, a colour grade that lifts warm highlights, subtle bloom, and a GUI vignette.

---

## Sound

19 looping 3D emitters are placed where the sound would really come from — drips in the pit,
wind in the rafters, timber settling in the wings, a faint piano through a wall, applause from a
house that isn't there. They pan and fade on their own as you move; no code runs per frame.

Each room gets its own reverb, cross-faded over 1.2s so it never switches with a click:

| Room | Tail | Feel |
| --- | --- | --- |
| The empty hall | 3.4s | rings |
| The painted street | 1.3s | short and dry, outdoors |
| Backstage | 2.1s | boxy timber |
| Lobby | 1.1s | small room |

Reverb is per player, so two people in different acts each hear their own room. Every sound ID
is a placeholder — see the README. Until you add them the game is silent and fully playable,
because every important cue is also captioned.

---

## Rules everything follows

1. **Decoration may never block or confuse the route.** Enforced by `clearance.spec`: standing
   room above every walking lane, the flight path of every jump, and the openings of exits and
   doors must be clear of solid geometry. It has caught nine real placement mistakes so far.
2. **The route must stay visible.** Enforced by `readability.spec`: every platform is styled with
   a `Route*` surface and must be measurably brighter than the set around it.
3. **Decoration is inert.** Everything decorative is anchored with collision, raycasts, touch and
   shadows off.
4. **Randomness is seeded.** All variation comes from `Config.Map.VisualSeed`, so the map looks
   hand-made but is identical every build. Change the seed to reshuffle it.
5. **One place to retune.** Every part's colour and material comes from `Theme.Surfaces`; a test
   fails if any part is styled outside it.
6. **Budgets are written down and checked.** `Config.Performance`: 12,000 parts, 30 lights and 6
   particle emitters per stage.

### Where it currently sits

| | Count | Budget |
| --- | --- | --- |
| Parts in the map | 3,203 | 12,000 |
| Lights per stage | 15–18 | 30 |
| Particle emitters per stage | 1–4 | 6 |
| Walkable platforms | 37 | — |
| Glow-tape edge markers | 44 | — |
| Ambience emitters | 19 | — |

---

## Where things live

```
src/shared/
  Theme.luau          Surfaces (every part's colour + material), Lighting mood, fonts
  Lore.luau           every word the environment says
  Config.luau         tunables: VisualSeed, Performance budgets, Quality levels, Ambience
src/server/MapBuilder/
  SetPieces.luau      reusable pieces: seats, curtains, arches, windows, rigging, beams, confetti
  LoreProps.luau      boards, playbills, tags, prompt book, scuffs, footprints
  Props.luau          doors, footlights, spotlights, signs, dust
  Set/Auditorium      Act I   ·  Set/Street  Act II  ·  Set/CurtainCall  Act III
  Set/Story.luau      places the lore and the hints
src/server/Services/
  AmbienceService     the 3D soundscape
src/client/
  Quality.luau        Low / Medium / High, Auto picks Low on mobile
  World/Ambient       one shared loop: swings, flicker, creaks, ripples
  World/Curtains      sway + ripple
  World/StageLight    scripted scare lighting
  Audio/AmbienceController   room reverb per stage
  Camera/Vignette     ambient edge vignette
  UI/DebugOverlay     F3 counts, F4 route gizmo (Studio only)
```
