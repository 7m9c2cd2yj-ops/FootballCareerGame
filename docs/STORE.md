# Store, purchases and the locker

The store sells **cosmetics** (boots, celebrations, kit colours) and one
**convenience** (three extra career save slots). Nothing in it affects how
the game plays. There are no ads, so there is no ad-free product.

## Rules (enforced by code and tests)

- Every product is a one-time (non-consumable) purchase with a fixed, listed
  content. There are no loot boxes, random rewards, currencies, energy or boosts.
- `StoreCatalog.validate` rejects:
  - any product key outside a fixed list, so `drop_chances` or `rating_bonus`
    cannot be added
  - any kind other than `cosmetic` or `convenience`
  - a cosmetic product that also grants slots, or the reverse
  - an unknown cosmetic, or one sold twice
  - a cosmetic kind with no free item
- `tests/unit/store/test_purchases_never_affect_play.gd` fails if any career
  or moment rule (all of `scripts/core/` except `store/` and `settings/`)
  refers to the store, entitlements, settings or cosmetics.
- `tests/ui/test_store_screens.gd` plays the same penalty with and without
  every cosmetic equipped and requires an identical result.
- Every purchase and every link out of the game is behind the parental gate
  (`ParentalGate`): a two-digit × one-digit multiplication answered by tapping
  one of four close choices. A wrong answer closes the gate.

## Files

| File | Role |
|------|------|
| `data/store.json` | Cosmetics, free items, products, **placeholder platform product IDs** |
| `scripts/core/store/store_catalog.gd` | Loads and validates the store file |
| `scripts/core/store/entitlements.gd` | What the player owns; extra slots; what may be equipped |
| `scripts/core/store/parental_gate.gd` | The grown-up question |
| `scripts/app/store.gd` | Autoload `Store`: **the single purchase wrapper** |
| `scripts/app/store_adapter.gd` | Interface to a platform store |
| `scripts/app/mock_store_adapter.gd` | Test purchases in debug builds (nothing is charged) |
| `scripts/ui/store_screen.gd`, `locker_screen.gd`, `parental_gate_dialog.gd` | Screens |

Owned products are stored in `user://store/entitlements.json`. Equipped items
are stored in the device settings, `user://settings.json`. Both are read
through `Entitlements`, which only ever equips something the player owns.

## Debug and release builds

Debug builds use `MockStoreAdapter`: purchases succeed at once and nothing is
charged. Release builds report "Purchases are not available in this build"
until a platform adapter is added. The game stays fully playable without one.

## Adding the platform stores (before release)

1. Create the products in App Store Connect and the Google Play Console as
   **non-consumable** in-app products. Put their IDs in `data/store.json` →
   `platform_ids` (the `com.example…` values are placeholders).
2. Install the platform billing plugin for Godot 4.7 and follow its own docs:
   - Android: the Godot Google Play Billing plugin
     (github.com/godot-sdk-integrations/godot-google-play-billing).
   - iOS: the Godot iOS in-app purchase plugin
     (github.com/godot-sdk-integrations/godot-ios-plugins, `inappstore`), or a
     maintained StoreKit 2 plugin.
3. Write one `StoreAdapter` subclass per platform in `scripts/app/`. Each one
   overrides `label`, `is_available`, `platform` (`"ios"` or `"android"`),
   `request_purchase` and `request_restore`, and emits `purchase_finished` /
   `restore_finished` when the store answers. Use only methods the plugin
   documents. Acknowledge or finish each transaction as that plugin requires.
4. Return the adapter from `Store._make_adapter()` when its plugin singleton
   exists, and keep the mock for debug builds.
5. Test on devices with sandbox / licence-tester accounts. The steps are in
   `docs/STORE_CHECKLIST.md`.

Entitlements are local and only unlock cosmetics, so a modified app gains
nothing that matters to other players: rankings are validated server-side
from career data and never include cosmetics.
