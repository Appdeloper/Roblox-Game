# Launch checklist

## Content & IDs
- [ ] Replace all 16 sound placeholders in `src/shared/Assets.luau` with audio you own or are
      licensed to use. Keep volumes gentle: the heartbeat should never be startling.
- [ ] (Optional) Dust and vignette image IDs in `Assets.Images`
- [ ] Create 3 badges and paste their IDs into `Config.Badges`. Badge art must be original.
- [ ] Create 2 game passes and 2 developer products and paste their IDs into `Config.Monetization`
- [ ] Set item prices on the Creator Dashboard. Keep them kid-friendly; everything is cosmetic.
- [ ] Bump `Config.Game.BuildLabel` (shown on the lobby wall)

## Safety & policy (ages 9–17)
- [ ] Complete the **Experience Questionnaire** (mild fear, no violence/blood/gore) and check
      the resulting maturity label
- [ ] Play the three scares as a younger player would. Each one must be captioned and skippable,
      with no jump-scare pops at the camera.
- [ ] Reduced Scares removes all shakes and flashes
- [ ] All shop text is honest about what you get. Nothing is pay-to-win or a stage skip.
- [ ] No external links, no user-generated text shown to others (only Roblox usernames on the
      leaderboard)
- [ ] All assets and props are original (the map is built from primitives in code)

## Technical
- [ ] `scripts/check.sh` passes, and CI is green on the release commit
- [ ] Game Settings → Security → **Enable Studio Access to API Services** (for testing)
- [ ] Studio manual pass: `docs/TESTING.md` sections 1–7
- [ ] **Test → Clients and Servers** with 2+ players: no cross-player catches, no errors
- [ ] Device emulator: iPhone SE, a large phone and a tablet. HUD inside safe areas, 60 FPS.
- [ ] Live test server (private): badges award, DataStores save across servers, purchases grant
      once
- [ ] Server size: start with 8–12 players (each player has their own mannequin)
- [ ] Analytics: confirm the `[Analytics]` events appear in live server logs. Optionally set
      `Config.Analytics.UseRobloxAnalytics = true`.

## Store page
- [ ] Icon and thumbnails (original art: the mannequin, the painted ★ door, the ticket)
- [ ] Description that mentions Reduced Scares and that it's spooky-fun, not gory
- [ ] Genre: Obby / Horror-lite. Devices: Phone, Tablet, Computer.

## After launch
- [ ] Watch the `caught` events per stage. If one stage dominates, tune its gaps, `Config.Door`
      timings or `Config.Catch.Distance`.
- [ ] Watch the `quit_stage` events by stage, which show where players give up.
- [ ] Check the DataStore error rate in the Creator Dashboard
