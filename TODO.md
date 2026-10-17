# TODO

Every `TODO` comment in the code must have a matching entry here.
Items are grouped by the milestone that will resolve them.

## Code TODOs

_None._

## Planned work not yet started

- [ ] M3: 3D moments (penalty, free kick, one-on-one, save) with pure-logic resolvers.
- [ ] M3: Feed moment results into `SeasonPerformance` instead of the
      expected rating alone (season screen currently plays expected rating).
- [ ] M4: Contracts, transfers, club needs and offers, Clubs app UI.
- [ ] M4: Replace the academy `competition_strength` table with the player's
      club/league strength from 21+, and handle retirement before `max_age`.
- [ ] M5: Phone UI, news, agent texts, Kickfie feed from templates.
- [ ] M6: World Nations Cup and Continental Cup simulation.
- [ ] M7: Local saves (one career per slot, backup copy), Supabase schema and
      RLS migrations, ranking-validation edge function, sync, ARENA.
- [ ] M7: Decide how the Supabase URL and anon key reach the exported build
      (env vars do not exist on device; bake them in at export time).
- [ ] M8: Android (AAB) and iOS export presets, with secrets read from env vars.
- [ ] M8: Onboarding with a preset/filtered name list (currently every career
      uses `default_player_name` from data/game_config.json).
- [ ] M8: Respect the device safe area (notches) in all portrait screens.
- [ ] M8: Text-size setting, color-blind-safe palette, haptics toggle.
- [ ] M8: Replace the privacy-policy placeholder URL and docs/PRIVACY_POLICY.md.
- [ ] M8: Measure the docs/PERFORMANCE.md budget on a real mid-range device.
