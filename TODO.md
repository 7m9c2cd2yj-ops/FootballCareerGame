# TODO

Every `TODO` comment in the code must have a matching entry here.
Items are grouped by the milestone that will resolve them.

## Code TODOs

_None._

## Planned work not yet started

- [ ] M8: Export presets must include `config/backend.local.json` and the
      `data/*.json` files (non-resource files need an include filter).
- [ ] M8: Extra save slots (convenience purchase) raise `free_save_slots`.
- [ ] M8: Onboarding picks the preset online name (Settings has it for now).
- [ ] Later: CAPTCHA on anonymous sign-up (Supabase Attack Protection) once
      the client sends a captcha token; community-room servers players can join.
- [ ] Later: Persist phone "seen" counts with the save (badges reset each session).
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
