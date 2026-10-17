# Store listing checklist

Work through this before each submission. Items marked **(code)** are already
handled in the project, so only check they still hold. Everything else needs
a person, an account or a device.

## Legal and content

- [ ] Final game name chosen, then set in `data/game_config.json` and `project.godot`
      (a test checks they match). Search trademarks for the name.
- [ ] **(code)** No real clubs, leagues, federations, players, logos or kits.
      `ContentRules` blocks a list of real names in text templates. Crests and
      kits are generated vector shapes.
- [ ] **(code)** "Unofficial fan game" disclaimer on the main menu and in
      onboarding. Add the same sentence to the store description.
- [ ] Screenshots and the preview video show only in-game, fictional content.
- [ ] Privacy policy written by a person with legal review. Hosted, with the URL set in
      `data/game_config.json` (`privacy_policy_url`) and in both store consoles.
      Replace `docs/PRIVACY_POLICY.md`.
- [ ] Support contact (email or web page) for both store listings.

## Children and families (COPPA, GDPR-K, Apple Kids, Google Families)

- [ ] Decide the audience. If children are included:
  - Apple: Kids category, with an age band.
  - Google: Families programme, with target ages.
- [ ] **(code)** No free-text input anywhere. Names come from
      `data/preset_names.json`, and the server accepts only those.
- [ ] **(code)** No chat and no user-generated content shown to others.
      The Kickfie feed is generated on the device.
- [ ] **(code)** Parental gate before purchases and before the privacy-policy link.
- [ ] **(code)** No ads, no analytics or tracking SDKs, and no advertising ID.
      The iOS preset has `privacy/tracking_enabled=false`.
- [ ] **(code)** Anonymous accounts only. In-app account deletion is in
      Settings → Delete my account.
- [ ] Apple privacy "nutrition label" and Google Data safety form, filled in from
      `docs/PRIVACY_POLICY.md`:
  - The anonymous user ID, the preset display name and gameplay data are
    collected only when online features are used.
  - None of it is used for tracking.
- [ ] iOS privacy manifest: check the required-reason API entries Godot adds
      for the export (`privacy/*_access_reasons` in the iOS preset).
- [ ] If any third-party SDK is added later, check that it is certified for
      families/kids. None is in use now.

## Purchases

- [ ] Products created as **non-consumable**, with IDs copied into
      `data/store.json` → `platform_ids`.
- [ ] **(code)** No loot boxes, random rewards, currencies or pay-to-win:
      `StoreCatalog` validation and `test_purchases_never_affect_play.gd`.
- [ ] Platform `StoreAdapter`s added (`docs/STORE.md`), with purchase, restore
      and interrupted purchase tested using sandbox / licence-tester accounts.
- [ ] Restore purchases works on a fresh install. Apple requires a visible
      Restore button, which is on the Store screen.
- [ ] Prices set. Store text says what each product contains.

## Builds and devices

- [ ] Real package / bundle IDs and versions set (`docs/RELEASE.md`).
- [ ] Release keystore created and backed up, and Play App Signing enrolled.
- [ ] App icons (all sizes) and splash screen replace the placeholders.
- [ ] Android target SDK meets the current Play requirement. The preset uses
      Godot's default unless `gradle_build/target_sdk` is set.
- [ ] Every item under "Needs manual test on device" in the latest milestone
      report has been run on at least one Android and one iOS phone.
- [ ] Performance table in `docs/PERFORMANCE.md` filled in from a mid-range device.
- [ ] Offline play checked in airplane mode: new career, a full season, saving.
- [ ] Online checked against the production Supabase project:
      `docs/SUPABASE_SETUP.md`, with backend tests run against it.

## Listing assets

- [ ] Title, subtitle / short description, full description (with the disclaimer).
- [ ] Phone screenshots in portrait (menus) and landscape (key moments) at the
      sizes each store requires. Tablet screenshots if tablets are supported.
- [ ] Feature graphic (Google Play, 1024×500).
- [ ] Age rating questionnaires (IARC / Apple). There is no violence,
      gambling or simulated gambling, and no user interaction.
- [ ] Category: Sports (game).
