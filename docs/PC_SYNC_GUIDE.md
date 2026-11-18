# PC sync guide (beginner friendly)

From a fresh Windows or Mac PC to playing *Don't Look Backstage* in Roblox Studio.
It takes about 20 minutes the first time. You don't need to edit any code to play.

---

## 0. Before you start (on your phone)

On GitHub, merge the open pull requests **in number order** (oldest first). Each one goes into
`main`. When they're all merged, `main` holds the whole game.

> Not merged yet? You can still play: in step 3, use the branch name from the newest PR instead
> of `main`.

---

## 1. Install the tools (once)

| Tool | Where | Notes |
| --- | --- | --- |
| **Roblox Studio** | <https://create.roblox.com> → **Start Creating** / **Download Studio** | Log in with your Roblox account. |
| **Git** | <https://git-scm.com/downloads> | Accept all the defaults. (Prefer clicking? **GitHub Desktop** from <https://desktop.github.com> also works.) |
| **VS Code** | <https://code.visualstudio.com> | The code editor. |
| **Rojo extension for VS Code** | In VS Code: the **Extensions** icon (four squares) → search **Rojo** → install the one by **evaera** | It installs the Rojo program **and** the Rojo Studio plugin for you. |

**Prefer the command line?** Install Rokit (<https://github.com/rojo-rbx/rokit>), then run
`rokit install` inside the project folder. That installs the exact Rojo version this repo pins
(7.4.4). Then run `rojo plugin install` to add the Studio plugin.

---

## 2. Check the Studio plugin is there

1. Open **Roblox Studio** → **New** → **Baseplate**.
2. Click the **Plugins** tab at the top. You should see a **Rojo** button.
   - Missing? In VS Code press `Ctrl+Shift+P` (Mac: `Cmd+Shift+P`), type **Rojo: Install Roblox
     Studio plugin**, press Enter, then restart Studio.

---

## 3. Get the code

Open a terminal (Windows: **Git Bash** or **PowerShell**; Mac: **Terminal**) and run:

```bash
git clone https://github.com/Appdeloper/Roblox-Game.git
cd Roblox-Game
```

Branch not merged yet? Run `git checkout <branch-name-from-the-newest-PR>` too.

Then open the folder in VS Code: **File → Open Folder… → Roblox-Game**.

---

## 4. Start Rojo (`rojo serve`)

**With the VS Code extension:** press `Ctrl+Shift+P` (Mac: `Cmd+Shift+P`) → **Rojo: Open menu**
→ click **default.project.json** to start it. A small panel says the server is running on port
**34872**.

**Or in a terminal** (inside the `Roblox-Game` folder):

```bash
rojo serve
```

Leave it running. You should see `Rojo server listening on port 34872`.

---

## 5. Connect Studio and press Play

1. In the Studio **Baseplate** from step 2, click **Plugins → Rojo**. A Rojo panel opens.
2. Click **Connect** (the address is `localhost`, port `34872`; don't change it).
3. Rojo copies the scripts in. You'll see `Main` appear in **ServerScriptService**, and
   `ReplicatedStorage → Shared`, `StarterPlayer → StarterPlayerScripts → Client`.
4. Open **View → Output** so you can see messages.
5. Press **Play** (or F5).

**What you should see:**
- Output prints `[Main] Don't Look Backstage ready: 3 stages`.
- You appear on a small wooden rehearsal stage with a glowing bulb, and a card that says
  "You wake up onstage…".
- The Baseplate is still there, far below you. That's normal: the game is built 400 studs up
  so it never touches it.
- You may see `[MapBuilder] disabled stray SpawnLocation` in Output. That's also normal (the
  template's spawn is switched off so you start in the lobby).

Saving won't work yet, and you'll see a "saving is paused" message. Step 6 fixes that.

Now follow **[FIRST_PLAYTEST.md](FIRST_PLAYTEST.md)** for the first 10 things to try.

---

## 6. Publish and turn on DataStores (saving and leaderboard)

1. Stop the game (**Stop** button).
2. **File → Publish to Roblox As…** → **Create new game** → give it a name → **Create**.
3. **Home → Game Settings → Security** → turn on **Enable Studio Access to API Services**
   → **Save**.
4. Press **Play** again. The "saving is paused" message should be gone, and after you finish a
   run your best time appears in the lobby and on the chalkboard.

Every time you change code later, keep Rojo connected (it syncs live), then **File → Publish to
Roblox** to update the live game.

---

## 7. Replace the placeholder IDs

Every placeholder is a `0`. Replace each `0` with the number ID from the Creator Dashboard
(<https://create.roblox.com/dashboard/creations>). Open the file in VS Code, press `Ctrl+G`
(Mac: `Cmd+G`) and type the line number to jump there. Rojo syncs the change to Studio
instantly.

### Sounds: `src/shared/Assets.luau`

Upload audio you made or are allowed to use (Creator Dashboard → **Development Items → Audio**),
or use free sounds from the Creator Store. Copy the number from the audio's page.

| Line | Sound | What it should sound like |
| --- | --- | --- |
| 19 | `Ambience` | Low, looping room tone / soft wind |
| 20 | `Heartbeat` | Soft heartbeat loop (the game speeds it up) |
| 21 | `MannequinCreak` | Looping wooden creak |
| 22 | `DoorCreak` | Door handle rattle + creak |
| 23 | `DoorOpen` | Door swinging open |
| 24 | `Knock` | One polite knock |
| 25 | `Applause` | Distant applause |
| 26 | `CaughtSting` | Clapperboard snap |
| 27 | `FellSting` | Soft "boing" |
| 28 | `TitleWhoosh` | Curtain whoosh |
| 29 | `FinishFanfare` | Short brass fanfare |
| 30 | `FakeExitBonk` | Cardboard thump |
| 31 | `CardboardCrumple` | Cardboard crumple |
| 32 | `BackdropRumble` | Rope and pulley rumble |
| 33 | `ShadowBow` | Soft violin swell |
| 34 | `UiClick` | Ticket punch click |

Optional images (same file): line **38** `DustParticle` (a soft round dot). Line **39**
`Vignette` is reserved and currently unused, so you can leave it as `0`.

The game is fully playable while these are `0`. It's just silent, and captions show every cue.

### Badges: `src/shared/Config.luau`

Creator Dashboard → your game → **Engagement → Badges → Create a Badge**, once for each:

| Line | Badge | Earned by |
| --- | --- | --- |
| 190 | `FirstEscape` | Escaping the theatre once |
| 191 | `OpeningNight` | Escaping with zero retakes |
| 192 | `SpottedTheDoor` | Getting past a painted door's exit before the mannequin comes out |

Badges are only given in the **live game**, not in Studio. Studio just prints a message.

### Game passes and products: `src/shared/Config.luau`

Creator Dashboard → your game → **Monetization → Passes** (game passes) and **Developer Products**:

| Line | Item | Type |
| --- | --- | --- |
| 205 | Spotlight Trail (`SpotlightTrail`) | Game pass |
| 210 | Velvet Curtain Border (`VelvetCurtainBorder`) | Game pass |
| 218 | Golden Ticket Skin (`GoldenTicketSkin`) | Developer product |
| 224 | Moonlit Ticket Skin (`MoonlitTicketSkin`) | Developer product |

All four are cosmetic only. Set the prices on the dashboard.

After replacing IDs: **File → Publish to Roblox**.

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Rojo **Connect** fails | Make sure `rojo serve` (or the VS Code Rojo menu) is still running. Check the port is 34872. Check your firewall allows it. |
| "Version mismatch" in the Rojo panel | Update the Studio plugin to match your Rojo version (`rojo plugin install`, or the VS Code command **Rojo: Install Roblox Studio plugin**). |
| Nothing happens on Play / no `[Main]` line | Check **ServerScriptService** contains `Main`, `MapBuilder` and `Services`. If not, reconnect Rojo. |
| "saving is paused" | Do step 6 (publish + Enable Studio Access to API Services). |
| You spawn on the grey Baseplate | Look in Output for errors from `MapBuilder` and send them to me. |
| Red errors in Output | Copy the first red line (with its script name and line number) and paste it into a GitHub issue or chat. |
