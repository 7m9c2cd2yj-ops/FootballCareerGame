# Balance and progression

All progression numbers live in `data/balance.json`. The formula lives in
`scripts/core/progression.gd`. Nothing uses randomness: the same choices and
the same match ratings always produce the same player.

## How a season works

1. The player picks a **primary** and a **secondary** training focus.
   The Season screen pre-selects `TrainingAdvisor`'s suggestion, which is the
   attributes with the best position weight × remaining headroom.
2. The season is played and produces a `SeasonPerformance`: matches played and
   an average match rating from 0 to 10. Until M3/M4 there are no 3D moments
   or clubs, so the rating is the deterministic **expected rating**:
   `neutral + (overall − competition strength) × per_overall_point`, clamped.
3. Every attribute changes by the formula below. Then the player ages one year.

## Formula (per attribute, per season)

```
growth phase (age_curve base_gain >= 0):
  change = (base_gain × focus + performance_bonus × used) × headroom
decline phase (base_gain < 0):
  change = base_gain × decline_weight × (1 − protection)
           + performance_bonus × used × headroom

focus             = training.primary / secondary / other_multiplier
protection        = training.primary / secondary_decline_protection (else 0)
headroom          = max(headroom.floor, ((99 − value) / 98) ^ headroom.exponent)
performance_bonus = max(0, rating − baseline_rating) × gain_per_point
                    × matches_played / matches_per_season
used              = 1 if the position's weight for the attribute > 0, else 0
```

Overall rating = position-weighted average of attributes, rounded.
Stored values are rounded to 2 decimals (`Progression.round_value`) so saves
reload exactly.

## Design targets (enforced by `tests/unit/test_balance_tuning.gd`)

| Play style (average match rating every season) | Target |
|---|---|
| Elite, 9.7 | reaches **99** between ages 25 and 30 |
| Star, 9.0 | peaks 95–99 |
| Good, 7.5 | peaks 80–90 |
| Unremarkable (expected rating, no standout moments) | peaks 55–72 |
| Perfect play at 18 | still below 85 (no teenage superstars) |
| Good play at 36 | at least 4 below the career peak |
| Position fairness | good-play and expected peaks within 4 of each other |

## Current curves (`./tools/balance_report.sh`)

| Position | Style | 12 | 16 | 20 | 24 | 28 | 32 | 36 | Peak@age |
|---|---|---|---|---|---|---|---|---|---|
| FWD | elite 9.7 | 40 | 65 | 85 | 95 | 99 | 98 | 95 | 99@28 |
| FWD | star 9.0 | 36 | 59 | 79 | 91 | 97 | 98 | 93 | 99@31 |
| FWD | good 7.5 | 29 | 47 | 63 | 76 | 84 | 87 | 82 | 88@31 |
| FWD | expected | 23 | 35 | 46 | 55 | 62 | 63 | 53 | 64@30 |

The other positions are within a few points. Run the report for the full table.

### M8 tuning pass

Midfielders trailed the other positions by 3–5 points at every play level
(expected peak 61 against 64–67). Their two training focuses covered only 55%
of their position weight, against 65–70% for the other positions. The midfield
weights are now passing 0.40, dribbling 0.25, shooting 0.10, pace 0.10,
defending 0.10 and physical 0.05. Two focuses now cover 65%, and the
midfield expected peak is 65. The fairness test now covers the expected
rating too, and it fails on the old weights.

## Career context

The curves above use the age tables in `balance.json` throughout (one flat
senior competition level). In a real career from age 18 the player faces
their club's league strength, plays fewer matches when rotated or benched,
and can be injured (see `docs/CAREER.md`).
`tests/unit/career/test_career_simulation.gd` checks whole careers with
all of that included.

## How to tune

1. Edit `data/balance.json`.
2. Run `./tools/balance_report.sh` to see whole careers per position and style.
3. Run `./tools/run_tests.sh`. If a tuning test fails, either adjust the numbers
   or change the target on purpose, in both the test and this file.

The loader rejects broken files with a readable message. Examples: an age
table with a gap, a missing attribute, or a weight below zero.
