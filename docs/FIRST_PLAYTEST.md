# First playtest: the first 10 things to check, in order

Do these right after [PC_SYNC_GUIDE.md](PC_SYNC_GUIDE.md) step 5. Keep **View → Output** open.
Each step has **correct** behaviour. If something doesn't match, note the step number, then
copy the first red error line from Output.

---

### 1. The server builds the map
**Do:** press **Play**.
**Correct:** Output shows `[Main] Don't Look Backstage ready: 3 stages`, and no red errors and no
`[MapBuilder] stage N layout:` warnings. You stand on a wooden rehearsal stage under a single
glowing bulb, and a card reads **"You wake up onstage. The house lights are off."**

### 2. The lobby works
**Do:** look around.
**Correct:**
- A chalkboard on the left wall titled **★ BEST ESCAPES ★**. It says "No escapes yet" or "The
  playbill is resting" until DataStores are on.
- A **STAGE DOOR** with "PLACES, PLEASE!" on the right wall.
- A **WARDROBE** rail.
- At the bottom of the screen: **▶ START THE SHOW** and **Wardrobe** buttons.

### 3. Starting a run
**Do:** walk to the stage door and press its prompt (or tap **START THE SHOW**).
**Correct:**
- A quick fade, then red curtains part on **ACT I · The Empty Auditorium**.
- A timer starts at the top and **🎬 RETAKES 0** shows at the top left.
- You stand on a glowing teal **X** at the back of a dark theatre.
- A pale wooden mannequin with a blank face stands still on a dark ledge to your **left**.

### 4. The mannequin waits while you stand still
**Do:** don't touch anything for 10 seconds.
**Correct:** the mannequin **does not move** and you are **not** caught.

### 5. The 1.5-second copy, then the catch
**Do:** walk forward about 5 steps, then stop.
**Correct:**
- About **1.5 seconds after you started walking**, the mannequin steps out and walks **your exact
  path**, with its legs swinging.
- Because you stopped, it reaches you about 1.5 s later.
- You see **"CUT! Take it from the top."**, a quick flash and shake, and RETAKES becomes **1**.
- Under a second later you're back on the X with a **"🎬 TAKE 2"** slate, and the mannequin is
  back on its ledge.
- Stand still again: you are **not** instantly re-caught.

### 6. Jumps feel fair
**Do:** run and jump across the tipped red-velvet seat rows toward the stage.
**Correct:**
- Every gap is easy with a normal running jump. None needs a pixel-perfect jump.
- If you keep moving, the mannequin stays about 1.5 s behind and never catches you.
- Falling into the fog shows **"Missed your mark!"**, sends you back to the X, and adds 1 retake.

### 7. The painted door shortcut
**Do:** reach the wide aisle landing next to the purple door with a **brass ★** on the right wall.
Keep going.
**Correct:** a second purple ★ door further along the same wall (near the orchestra rail):
1. its **handle turns** up and down,
2. **warm light glows under it**,
3. about 1.6 s or more later it **swings open** and the mannequin steps out.

If you were already past that door: **"You outran the painted door!"**

### 8. The stage 1 scare and the next stage
**Do:** climb the two prop trunks onto the stage and walk to the middle.
**Correct:**
- A spotlight fades up. A big dark **shadow** of a figure on the back curtain **bows**.
- The caption **"…and something behind you finishes the bow."** appears, and the mannequin
  behind you bows.
- It does **not** catch you during this, and a **Skip ▸** button is available.
- Walk into the glowing **BACKSTAGE** arch: **ACT II · The Painted Street** appears.

### 9. Stage 2 pieces
**Do:**
- Climb the wooden ladder marked **UP ↑**.
- Cross the four shop roofs.
- Drop onto the blue mat.
- Run toward the hanging blue backdrop.

**Correct:**
- On the first roof: **"Look up! Someone is walking past the upstairs windows…"**, and a
  mannequin walks past four lit windows.
- On the **blue mat you slide down toward the landing**, not back toward the roofs. *(If you
  slide the wrong way, that's [KNOWN_RISKS](KNOWN_RISKS.md) #3.)*
- The backdrop **slowly lowers**. You can run under it before it closes. If it closes, it rises
  again in a few seconds.

### 10. Stage 3, the finish ticket, and phone controls
**Do:**
- Run down the cardboard stairs.
- Touch the exit **without** light under it, then the one **with** light.
- Stop, then press **Play** again using **Test → Device → iPhone** (the mobile emulator).

**Correct:**
- Stairs wobble then drop away behind you.
- On the stage floor: **"Knock."** then **"…then applause from the empty seats."**
- The unlit door shows **"It's only paint!"**.
- The lit door takes you to the lobby with a **theatre ticket** showing your time, retakes and a
  seat. With 0 retakes it shows **★ Opening Night ★**.
- In the emulator:
  - a big amber **JUMP** button sits bottom-right and works when held
  - the timer, retakes and ⚙ sit below the Roblox buttons and the notch
  - ⚙ → **Reduced scares** removes the flash and shake when you're caught

---

All 10 pass? Next: walk the **[visual checklist](VISUAL_CHECKLIST.md)** — it covers the
environment in detail (lighting, the story props, each act, the living theatre, the scares,
performance and mobile).

Then:
- Do **Test → Clients and Servers → 2 Players** ([TESTING.md](TESTING.md) section 2).
- Turn on DataStores ([PC_SYNC_GUIDE.md](PC_SYNC_GUIDE.md) step 6).
