# Testing

## Automated (runs in CI on every push)

```bash
scripts/check.sh          # or: BIN=/path/to/tools scripts/check.sh
```

| Step | What it proves |
| --- | --- |
| `stylua --check src tests` | Formatting |
| `selene src` | Roblox-aware lint. It catches wrong `Enum` items, unknown globals, deprecated APIs and misused std functions. |
| `luau tests/run.luau` | Config sanity, jump math, every stage layout passing the **70% jump rule**, time formatting |
| `rojo build` | The project tree is valid and the place builds |
| `lune run tests/smoke/run build/DontLookBackstage.rbxl` | The real modules run: map build, mannequin behaviour (delay, catch timing, grace, scare hold, door shortcut), full server runs (escape, caught, fell, died, fake exit, two players, leave mid-chase, malformed/spammed remotes), DataService (merge, retry, failed-load lockout, migration, shutdown flush), leaderboard and badges, purchases (idempotent receipts), and the whole client UI |

The automated tests **can't** judge physics feel, camera, touch ergonomics, real DataStore or
Marketplace behaviour, or how scary something feels. The manual tests below cover those.

---

## Manual tests in Roblox Studio

### 0. Setup (once)

1. `rojo build default.project.json -o DontLookBackstage.rbxl` and open the file in Studio.
2. `rojo serve`, then **Plugins → Rojo → Connect**.
3. Publish the place once (**File → Publish to Roblox**), then **Game Settings → Security →
   Enable Studio Access to API Services**. This is needed for DataStore tests 5 and 6.
4. Open **View → Output**. You should see:
   - `[Main] Don't Look Backstage ready: 6 stages`
   - no `[MapBuilder] stage N layout:` warnings
   - `[Main] 18 asset placeholders still to replace` (until you add sound IDs)

### 1. Solo playthrough (Play, F5)

| # | Do | Expect |
| --- | --- | --- |
| 1.1 | Press Play | You spawn on the small rehearsal stage under a glowing bulb. An intro card reads "You wake up onstage…". A chalkboard (left wall) says "Loading the playbill…" then lists times or "No escapes yet". |
| 1.2 | Walk to the STAGE DOOR (right wall). Press the prompt, or press **START THE SHOW**. | A fade, then the "ACT I · The Empty Auditorium" curtain card. The timer starts and RETAKES shows 0. The mannequin stands on the dark ledge to your left. |
| 1.3 | Don't move for 10 s | You are **not** caught (the mannequin waits until you leave the spike mark). |
| 1.4 | Walk forward a few steps, then stand still | About 1.5 s later the mannequin walks your exact path and catches you: "CUT! Take it from the top", a flash and shake, retakes = 1, then back at the entrance with a "TAKE 2" slate. |
| 1.5 | Immediately stand still again | No instant re-catch: 3 s of grace, and recording only restarts when you move. |
| 1.6 | Jump along the seat rows | Every gap is comfortably jumpable. Nothing should need a perfect running jump. |
| 1.7 | Reach the aisle landing beside the purple ★ door on the right wall | At the next ★ door further along the wall (by the orchestra rail), the handle turns, warm light shows under it, and you hear a creak (if audio is set). About 1.6 s or more later it swings open and the mannequin steps out. If you were already past it: "You outran the painted door!" |
| 1.8 | Fall off a seat row into the fog | "Missed your mark!", back to the entrance, retakes +1 |
| 1.9 | Climb the trunks onto the stage, walk to centre stage | A spotlight fades up, your shadow bows on the back curtain, then the caption "…something behind you finishes the bow." The mannequin bows behind you and does **not** catch you during this. |
| 1.10 | Walk into the glowing BACKSTAGE arch | ACT II card |
| 1.11 | Climb the ladder (UP ↑), cross the roofs | On roof A: "Look up!" A mannequin silhouette walks past the 4 upstairs windows. Then "A brass handle beside the landing starts turning." |
| 1.12 | Drop onto the blue slide mat | You slide down to the landing (low friction). |
| 1.13 | Approach the backdrop | It lowers over about 3.4 s. Get under it before it closes. If it closes, it rises again within about 3 s and repeats while you wait. |
| 1.14 | Stage door → ACT III | Two EXIT doors at the far end. Only one has light under it (random each run). |
| 1.15 | Run down the cardboard stairs | Each step wobbles when touched and drops about 0.7 s later. Falling sends you back (retake). Steps reset when you respawn. |
| 1.16 | Reach the stage floor | "Knock." from the unlit door, then applause and bouncing seats. Captions for both. |
| 1.17 | Touch the unlit exit | "It's only paint!", a small bump, no finish |
| 1.18 | Enter the lit exit | You're back in the lobby with the ticket: escape time, retakes, seat, best, "NEW BEST!" stamp, ★ Opening Night ★ if you had 0 retakes. |
| 1.19 | Press **Encore!** | A new run starts at ACT I. |
| 1.20 | ⚙ → **Reduced scares** on, replay stage 1 and get caught | No flash and no shake. Captions still show, and the proximity edge tint is steady instead of pulsing. |
| 1.21 | ⚙ → **Leave the show** mid-run | Back to the lobby. Output shows `[Analytics] quit_stage … reason=requested`. |
| 1.22 | Reset the character (Esc → Reset) mid-run | You respawn at the current stage entrance, retakes +1. |

Analytics: Output should show `[Analytics] stage_started`, `stage_cleared`, `caught`, `quit_stage`
and `finished` lines with sensible values.

### 2. Multiplayer: **Test → Clients and Servers → 2 Players → Start**

| # | Do | Expect |
| --- | --- | --- |
| 2.1 | Start runs on both clients | Each player has **their own** mannequin. On each screen the other player's mannequin is faded (75% transparent). |
| 2.2 | Player 1 stands still, Player 2 keeps moving | Only Player 1 is caught. Player 2's retakes don't change. |
| 2.3 | Player 1 triggers a painted door | Only Player 1 sees that door's handle and light. |
| 2.4 | Both on stage 3 | A step collapsing under Player 1 does not collapse for Player 2. |
| 2.5 | Close Player 2's window mid-chase | Player 2's mannequin disappears. The server shows `quit_stage … reason=left_game` and no errors. |
| 2.6 | Server window: watch Output for 2 minutes | No errors, no warnings spam. Autosave runs quietly. |

### 3. Mobile emulator: **Test → Device** (try iPhone SE, iPhone 14 Pro Max, iPad, a small Android)

| # | Check | Expect |
| --- | --- | --- |
| 3.1 | HUD | Timer, retakes and ⚙ sit below the Roblox top bar and clear of the notch / Dynamic Island. Nothing is clipped in portrait or landscape. |
| 3.2 | Jump button | A large amber **JUMP** circle bottom-right, easy to hit with a thumb. Roblox's small jump button is hidden. Holding it keeps jumping. |
| 3.3 | Thumbstick | Title cards and captions don't block the movement stick (you can move while a card is up). |
| 3.4 | Text | Captions are readable at arm's length, at least about 16 px on the smallest device. |
| 3.5 | Modals | Settings, Wardrobe and the ticket fit on screen. Every button is at least 64 px. |
| 3.6 | Performance | **View → Stats / MicroProfiler** in the emulator shows about 60 FPS in each stage. |

### 4. Scares, age-appropriateness pass

Play all three scares with sound on, at night, as if you were 9. Each must:

- be announced by a caption
- be skippable (Skip ▸)
- never pop anything at the camera
- not block movement

The mannequin never catches you while a scare plays.

### 5. Data (needs API access, see step 0.3)

| # | Do | Expect |
| --- | --- | --- |
| 5.1 | Finish a run, stop, Play again | The lobby panel shows "Your best escape: …", and your titles and skins persist. |
| 5.2 | Equip a skin, toggle Reduced Scares, rejoin | Both remembered |
| 5.3 | Turn **API access off**, Play | Notice: "saving is paused this visit". The game is still fully playable. |
| 5.4 | Turn API access back on, Play | The original profile is intact (5.3 did not overwrite it). |
| 5.5 | Press Stop mid-run | Output shows no DataStore errors (BindToClose flush). |

### 6. Leaderboard & badges

- Finish a run (longer than 20 s). Within about a minute the chalkboard lists your username and time.
- Badges are **not** awarded in Studio. Output prints `badge ID is a placeholder` until IDs are set.
  Verify badges in a live test server after publishing.

### 7. Purchases (Studio test purchases are free and simulated)

| # | Do | Expect |
| --- | --- | --- |
| 7.1 | Set real IDs in `Config.Monetization`. Open Wardrobe → buy Golden Ticket. | The prompt shows. After it completes, the Golden card says "Equip". Output shows `[Analytics] purchase product=GoldenTicketSkin`. |
| 7.2 | Buy the Spotlight Trail pass | A warm trail and glow follow your character. The card toggles it on/off. |
| 7.3 | Equip Velvet Curtain / Golden, finish a run | The ticket uses that skin. |
| 7.4 | Confirm fairness | No item changes speed, jump, timer or stages. |
