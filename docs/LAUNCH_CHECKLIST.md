# Launch checklist — Don't Look Backstage

Work top to bottom. Everything in **IDs to fill in** degrades gracefully while it's `0`: the game
stays silent, badges are logged instead of awarded, and shop items say "isn't on sale yet".

---

## 1. Publish once (unlocks saving and boards)

- [ ] Studio → **File → Publish to Roblox As…** → new experience.
- [ ] **Game Settings → Security → Enable Studio Access to API Services** (DataStores in Studio).
- [ ] Play once in Studio: Output should show no `[DataService] DataStores unavailable` line, and the
      lobby boards (Best Escapes, Today's Daily Run, Endless) should say "No escapes yet" instead of
      "resting".

## 2. IDs to fill in (exact file and line)

All in `src/shared/Config.luau` unless stated. Line numbers are for the commit this checklist
ships with. Search for the key name if they've moved.

### Badges (Creator Dashboard → your experience → Engagement → Badges)

| Badge | Line | Earned by |
| --- | --- | --- |
| `FirstEscape` | 326 | Escape the theatre |
| `OpeningNight` | 327 | Escape with zero retakes |
| `SpottedTheDoor` | 328 | Outrun a painted-door shortcut |
| `StareDown` | 329 | Make a mannequin lunge, then still clear the stage |
| `MirrorMirror` | 330 | Run past your reflection until it cracks |
| `FullHouse` | 331 | Clear Opening Night |
| `DailyDouble` | 332 | Finish a Daily Run |
| `DailyDevotee` | 333 | Visit three days in a row |
| `EndlessTen` | 334 | Clear 10 stages in one Endless run |
| `CastParty` | 335 | Finish Co-op with a friend |
| `RevivalAct` | 336 | Revive a teammate in Co-op |

Badge art must be original: a brass star on a painted door, a cracked mirror, a ticket stub.

### Game passes (Monetization → Passes)

| Pass | Line | Grants |
| --- | --- | --- |
| `SpotlightTrail` | 494 | Spotlight trail |
| `VelvetCurtainBorder` | 499 | Velvet Curtain ticket skin |
| `PlaybillCollection` | 505 | Starlight + Gaslight playbill backgrounds |

### Developer products (Monetization → Developer Products)

| Product | Line | Grants |
| --- | --- | --- |
| `GoldenTicketSkin` | 512 | Golden ticket skin |
| `MoonlitTicketSkin` | 518 | Moonlit ticket skin |
| `SparklerTrail` | 524 | Sparkler trail |
| `MarbleMannequin` | 530 | Marble skin for your Copycat |

Prices are set on the Creator Dashboard (display names in Config are in-game only). Keep them
kid-friendly; everything is cosmetic, and a config test fails the build if anything for sale
grants more than a skin or cosmetic.

### Audio and images (`src/shared/Assets.luau`)

- [x] All 24 sounds are filled from Roblox's own licensed library on the Creator Store
      (Pro Sound Effects and Roblox uploads), and each was checked loading in Studio. Swap in
      your own any time.
- [ ] 2 optional images (dust mote, vignette) are still `Id = 0`; built-in fallbacks are used.
      Upload your own audio or use Creator Store audio you are licensed to use. Studio prints how
      many placeholders remain at boot.
- [ ] Keep it gentle: the heartbeat and stings must never be startling at full volume.

### Build label

- [ ] `Config.Game.BuildLabel` (line 18): bump it for each release (shown on the lobby wall).

## 3. Store page

**Title:** Don't Look Backstage 🎭

**Description (draft):**
> You wake up on a rehearsal stage. A wooden mannequin copies your every move, 1.5 seconds late.
> Stop moving and it catches you. Look at it and it freezes… but stare too long and the lights
> flicker.
>
> 🎭 6 stages: the Empty Auditorium, the Painted Street, Curtain Call, the Flies, the Prop Room and
> Opening Night
> ☀ Daily Run · ∞ Endless · 👥 Co-op for 4
> 🏆 11 trophies, ticket stubs, trails and mannequin skins to earn
> 🎥 Clip Mode and photo spots for your best escapes
>
> Spooky-fun, no gore. Turn on Reduced Scares in Settings for no shakes or flashes.

**Genre:** Obby / Platformer (secondary: Horror, mild). **Max players:** 12 (co-op parties of 4).

### Icon and thumbnails (use real in-game screenshots)

Take them with **Clip Mode** on (🎥 button: no HUD) at **High** quality, in a published server
so the lighting matches what players see. 1920×1080 for thumbnails, 512×512 for the icon.

| Asset | Shot | Where |
| --- | --- | --- |
| Icon | Your mannequin's face close up, mid head-tilt, one warm spot from above, dark background | Stage 1: stand still on the seat rows and let it reach for you |
| Thumbnail 1 | You running across the catwalk, a light-rig beam sweeping just behind | Stage 4, catwalk B (see `docs/screenshots/stage4_flies.png`) |
| Thumbnail 2 | The finale: five exit doors, the full cast behind you | Stage 6 main stage, just after the house lights come up |
| Thumbnail 3 | The Mirror: your reflection walking at you across the roofs | Stage 2, roof B |
| Thumbnail 4 | Co-op: one player downed (frozen) and a friend running to revive them | Any stage, 2 players |

Text overlay (optional, big and short): **"DON'T LOOK."** / **"IT COPIES YOU."**

## 4. Experience settings

- [ ] **Experience Questionnaire**: mild fear themes, no violence, no blood, no gore. Check the
      resulting maturity label.
- [ ] **Avatar**: R15 or R6 both work.
- [ ] **Private servers**: on, free (or 0 Robux), so friends can play Co-op together.
- [ ] **Allow copying**: off. **Team Create**: as you like.
- [ ] **Communication**: the game shows no user-generated text (only usernames on the boards).
- [ ] **Devices**: Phone, Tablet, Computer, Console. Auto quality picks Low on touch.

## 5. Safety and policy (ages 9–17)

- [ ] Play all six scares as a younger player would: each is captioned and skippable, nothing pops
      at the camera.
- [ ] **Settings → Reduced Scares** removes every shake and flash (stare lunges become a gentle dim).
- [ ] Shop text is honest; nothing is pay-to-win or a stage skip (enforced by `tests/config.spec.luau`).
- [ ] No external links; all assets are original (the map is built from primitives in code).

## 6. Technical go/no-go

- [ ] `scripts/check.sh` passes and CI is green on the release commit.
- [ ] Studio: **Test → Clients and Servers** with 2+ players. Co-op gather, downed/revive, no
      cross-player catches, Output clean.
- [ ] Studio: **Device Emulator** on a small phone, a large phone and a tablet. HUD inside the safe
      areas, the mode buttons and the jump button are reachable, and the frame rate holds on Low.
- [ ] Private live server: badges award, DataStores save across servers (streak, trophies),
      purchases grant once, and the Daily board only takes your first run.
- [ ] Re-read `docs/KNOWN_RISKS.md` and tick off what you've seen with your own eyes.

---

## 10 Reel / Short ideas (with the exact moment to record)

Record with **Clip Mode** on, phone held vertically (or crop 9:16), Reduced Scares **off**.
Keep each one under 15 seconds and open on the hook.

1. **"It copies you."** Stage 1. Jump across three seat rows, then stop dead and turn around. The
   mannequin lands the same three jumps 1.5 s later and reaches for you. Cut on the "CUT! Take it
   from the top" card.
2. **"Don't look at it."** Any stage. Turn the camera onto your mannequin: it freezes mid-step.
   Keep staring as the stare meter fills… the lights flicker and it lunges. Text: *"I said don't
   look."*
3. **"Which door is real?"** Stage 6. Run at the five doors with the whole cast behind you. Hit a
   fake one (BONK, "It's only paint!"), swerve, take the real one. Caption: *"1 in 5."*
4. **"My reflection walked at me."** Stage 2, roofs B–D. Film the Mirror walking toward you as you
   walk toward it, then it cracks just before the slide mat.
5. **"The audience stood up."** Stage 6 signature scare. Stand on the main stage as the house
   lights come up and every seat full of mannequins rises. Pan the camera across them.
6. **"The light rig dropped."** Stage 4, catwalk D. The rig crashes on its chain and its spotlight
   snaps onto you. Then cross the next beam gate with a split-second to spare.
7. **"Near miss."** After any close escape, open **😱 Near-miss replay** on the finish ticket and
   screen-record the slow-motion orbit. Text: *"0.3 seconds."*
8. **"The costumes turned."** Stage 5, on the conveyor: every costume on the rail swivels to look at
   you while the belt drags you backwards.
9. **"Revive me!!"** Co-op with a friend. Get caught (downed), film your friend sprinting back past
   their own mannequin to revive you. Split screen if you can.
10. **"Day 7."** The trophy shelf and wardrobe after a week-long streak: Porcelain mannequin,
    Midnight playbill, trophies lit up. Then a quick **📸 Strike a pose** on the lobby photo spot.
