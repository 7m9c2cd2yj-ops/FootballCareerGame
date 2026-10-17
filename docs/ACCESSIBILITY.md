# Accessibility and settings

Settings → Accessibility. Choices are saved in `user://settings.json`
(`PlayerSettings`). A damaged file falls back to defaults one value at a time.

| Setting | Effect | Where |
|---------|--------|-------|
| Text size (Normal 1.0, Large 1.15, Largest 1.3) | Scales the whole UI (`Window.content_scale_factor`) | `data/accessibility.json`, `ScreenFit` |
| Colours: Standard / Colour-blind safe | Kits, aim marker, power bar, result text, badges, highlights | `data/accessibility.json` palettes |
| Vibrate on key-moment results | Short pulse on success, shorter on failure (phones only) | `Preferences.pulse`, `Input.vibrate_handheld` |
| Show the tutorial again | Re-runs onboarding and the per-moment tips | `Preferences.replay_tutorial` |

- The colour-blind palette uses only Okabe-Ito colours. Tests check that the
  player kit, opponent kit and keeper kit, and success and failure, stay
  clearly apart in every palette, and that every buyable kit colour stays
  clear of opponents and keepers.
- `tests/ui/test_large_text.gd` opens every portrait screen at the largest
  size and fails if any screen needs more width than a phone has.
- **Safe area:** on phones, `ScreenFit` adds the notch and home-bar insets
  (`DisplayServer.get_display_safe_area`, converted by `SafeArea.margins`) to
  every control in the `safe_area` group. That group holds each screen's
  content node and the moment HUD. Backgrounds still fill the whole screen.
- **Onboarding** (first Play):
  - Pick a preset name, used for new careers and online.
  - Read how a career works.
  - Optionally play a practice penalty that is never recorded.
- **Tips:** each moment type shows a "How to play" card the first time. The
  moment waits until it is closed.
- Text never relies on colour alone: results are written out ("GOAL!",
  "Saved"), and badges show numbers.
