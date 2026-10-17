# TODO

Every `TODO` comment in the code must have a matching entry here.
Items are grouped by the milestone that will resolve them.

## Code TODOs

_None._

## Before store release (needs accounts, plugins or devices)

- [ ] Platform purchase adapters: one `StoreAdapter` per platform using the
      Google Play Billing and iOS in-app purchase plugins, returned from
      `Store._make_adapter()` (steps in docs/STORE.md). Release builds say
      purchases are unavailable until then.
- [ ] Replace placeholders: product IDs (data/store.json), package/bundle IDs
      (export_presets.cfg), privacy-policy URL (data/game_config.json) and
      docs/PRIVACY_POLICY.md, app icons.
- [ ] Measure the docs/PERFORMANCE.md budget on a real mid-range device and
      fill in the table.
- [ ] Work through docs/STORE_CHECKLIST.md.

## Later

- [ ] Moment polish: player models and animations instead of capsules, sound
      effects.
- [ ] Optional 3D resolution scale for weak devices, if device tests need it.
- [ ] CAPTCHA on anonymous sign-up (Supabase Attack Protection) once the
      client sends a captcha token; community-room servers players can join.
- [ ] Persist phone "seen" counts with the save (badges reset each session).
