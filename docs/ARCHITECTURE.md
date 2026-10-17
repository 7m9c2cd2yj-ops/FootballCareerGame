# Architecture

## Layers

| Layer | Folder | May use | Must not use |
|-------|--------|---------|--------------|
| Data | `data/` | JSON only | Logic |
| Core logic | `scripts/core/` | `RefCounted`/`Resource`, `FileAccess`, `JSON`, math | `Node`, scene tree, `Input`, autoload singletons |
| App state | `scripts/app/` | Autoload `Session`: loaded data and the active career | Game rules |
| UI and 3D | `scenes/`, `scripts/ui/` | Everything; calls into core | Game rules (no balance numbers or formulas) |
| Backend | `backend/` | Supabase SQL and edge functions | Trusting anything the client sends |

`tests/unit/test_architecture.gd` scans `scripts/core/` for forbidden patterns
(`extends Node`, `get_tree(`, `Input.` and others) and fails the build if it
finds any.

## Rules

- **Determinism.** Core logic never calls a random number generator. Outcomes
  depend only on inputs (player state, choices, the player's real-time
  performance in a 3D moment). Cup simulations that need variety derive it
  from deterministic inputs such as a career seed and the fixture, never
  from `randf()`.
- **Data over code.** Tunable numbers live in `data/*.json` and are loaded
  through `JsonLoader`. Loading code validates the data and reports readable
  errors.
- **Exact saves.** Floats that get stored are rounded with
  `Progression.round_value`, so a career survives a JSON round trip exactly.
- **Untrusted input.** Data loaded from disk (and later the network) goes
  through `validate_dict` before `from_dict`, which assumes valid data.
- **Static typing.** Every variable, parameter and return value is typed.
  `untyped_declaration` is an error in `project.godot`.
- **Thin scenes.** A scene script reads input, calls core logic and displays
  the result. When a scene script grows rules, move them to `scripts/core/`.
- **Offline first.** The whole career works without a network. Sync and the
  ARENA fail gracefully (M7).
- **Never trust the client.** Rankings are validated server-side (M7).

## Error handling

Core functions return results (`JsonLoader.LoadResult`, or `null` plus an
`errors` list) instead of calling `push_error`. The UI layer decides how to
report the problem. GUT fails any test that raises an unhandled engine error
or `push_error`, so a passing test also means no hidden errors.
