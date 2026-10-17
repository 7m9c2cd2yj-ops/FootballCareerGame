# TODO

Every `TODO` comment in the code must have a matching entry here.
Items are grouped by the milestone that will resolve them.

## Code TODOs

_None._

## Planned work not yet started

- [ ] M5: Phone UI, news, agent texts, Kickfie feed from templates (events:
      trials, transfers with fees, renewals, injuries, retirement, Hall of Fame).
- [ ] M5: Move the Clubs app inside the phone UI shell.
- [ ] M6: World Nations Cup and Continental Cup simulation.
- [ ] M6: Add trophies and the Golden Ball to the Hall of Fame score.
- [ ] M7: Loading a save must run `CareerMigration.migrate` before
      `CareerState.validate_dict`.
- [ ] M7: Local saves (one career per slot, backup copy), Supabase schema and
      RLS migrations, ranking-validation edge function, sync, ARENA.
- [ ] M7: Decide how the Supabase URL and anon key reach the exported build
      (env vars do not exist on device; bake them in at export time).
- [ ] M8: Android (AAB) and iOS export presets, with secrets read from env vars.
- [ ] M8: Onboarding with a preset/filtered name list (currently every career
      uses `default_player_name` from data/game_config.json).
- [ ] M8: Respect the device safe area (notches) in all portrait screens.
- [ ] M8: Text-size setting, color-blind-safe palette, haptics toggle; then add
      haptic feedback on moment results (none yet, so there is nothing to toggle).
- [ ] M8: Moment polish: player models and animations instead of capsules,
      ball visible at the start of one-on-ones, sound, a short tutorial per moment.
- [ ] M8: Replace the privacy-policy placeholder URL and docs/PRIVACY_POLICY.md.
- [ ] M8: Measure the docs/PERFORMANCE.md budget on a real mid-range device.
