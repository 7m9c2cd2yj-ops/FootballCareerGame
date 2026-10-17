# Building for Android and iOS

`export_presets.cfg` holds two presets, configured as far as possible without
secrets. Option names were checked against the Godot 4.7.2 export plugins.

| Preset | Output | Notes |
|--------|--------|-------|
| Android | `build/android/kickoff_legacy.aab` | Gradle build, AAB, permissions INTERNET (online features) and VIBRATE (haptics). Backup of user data off. |
| Web | `build/web/index.html` | Browser version for quick play; see `docs/WEB.md` |
| iOS | `build/ios/KickoffLegacy.ipa` (Xcode project) | App Store export method, tracking off. Team ID left empty on purpose. |

Both presets include `data/*.json` and `config/backend.local.json`. Neither
is a Godot resource, so each needs the include filter. Both exclude
`tests/`, `tools/`, `addons/gut/`, `backend/`, `docs/` and `build/`.
`./tools/check_export.sh` (also in CI) exports the data pack for both presets
and checks this. It needs no export templates or SDKs.

## Before the first build (placeholders to replace)

- `package/unique_name` (Android) and `application/bundle_identifier` (iOS):
  `com.example.kickofflegacy` → your real reverse-domain ID.
- `version/code` / `application/version`: raise on every store upload.
  `version/name` / `application/short_version` should match `data/game_config.json`.
- Product IDs in `data/store.json` (see `docs/STORE.md`).
- Privacy policy URL in `data/game_config.json`.
- App icons: `icon.svg` is a placeholder. Add the platform icon sets in the presets.

## Signing (never commit secrets)

Android release signing comes from environment variables, which Godot reads
in place of the preset fields (`EditorExportPreset::get_or_env`):

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/secure/path/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>
# optional, for signed debug builds:
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=...  # _USER / _PASSWORD as above
```

Keystores are git-ignored (`*.keystore`, `*.jks`). Godot writes typed-in
passwords to `.godot/export_credentials.cfg`, which is never committed (`.godot/` is ignored).

iOS signing: set the Apple Developer Team ID in the editor on the build
machine, or in a local copy of the preset. Don't commit it. Let Xcode manage
the provisioning profiles.

## Build steps

1. Install the Godot 4.7.2 export templates (Editor → Manage Export Templates).
2. Android: install the Android build template (Project → Install Android
   Build Template), set the Android SDK path in Editor Settings, export the env vars above, then:
   `godot --headless --export-release "Android" build/android/kickoff_legacy.aab`
3. iOS (on a Mac with Xcode):
   `godot --headless --export-release "iOS" build/ios/KickoffLegacy.ipa`. Then
   archive and upload from Xcode.
4. For online builds, run `tools/write_backend_config.sh` first
   (`docs/SUPABASE_SETUP.md`). Without it the build is offline-only, which is
   allowed.
5. Work through `docs/STORE_CHECKLIST.md`.
