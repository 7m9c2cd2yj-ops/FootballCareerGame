# Career: academy, trials, contracts, transfers, injuries, retirement

Rules live in `scripts/core/career/`. The world is in `data/clubs.json` and
the numbers are in `data/career_rules.json`. Nothing is random.

## Phases

| Age | Phase | What happens |
|---|---|---|
| 8–15 | Academy | You play for the academy club (`academy_club`). The Clubs app already shows what every club wants. |
| 16 | Trials | **One** trial per career. You pass if `overall + key moments won last season × bonus ≥ club's youth_intake_min`. Passing signs a youth contract there. Failing signs one with the academy club. |
| 16+ | Pro | Each transfer window (between seasons), clubs whose open needs you meet make offers. Contracts tick down one year per season. |
| 33+ | Retirement | You may retire. At 40 the career ends. The Hall of Fame verdict follows. |

The season screen explains why you can't play: trials are due, your contract
has ended, or your career is over. The Clubs app is where you act on it.

## Club needs and offers

- Each club lists **needs**: position, minimum overall and an optional
  maximum age. Each window only some needs are open (`needs.open_share`).
  Which ones is decided by a fixed hash of the season and club, so they vary
  between seasons but are identical on every replay. At least one is always open.
- A club offers a contract if one of its open needs fits you:
  - **Wage** = `budget.wage_base × (1 + points above the need × wage_per_point_above_need)`.
  - **Years** follow `contract_years` by age.
  - **Release clause** = wage × `release_clause_multiplier`.
  - **Role** compares your overall with the club's strength. Within
    `starter_margin` you start; within `rotation_margin` you rotate;
    otherwise you sit on the bench. The role sets the share of matches you play.
- When your contract has run out:
  - Your club offers a **renewal** if you are within `renewal_margin` of its strength.
  - The community club (`fallback_club`) always offers, so nobody is stranded.
- Moving **mid-contract** needs the buying club's `transfer_budget` to cover
  your release clause. The fee is recorded in your transfer history.
- Clubs in lower leagues never pay a higher base wage than clubs above them.
  This is enforced by a test.

## Competition level

Before `senior_age` (18) the academy and youth tables in `balance.json`
apply. From 18, you face your **league's strength**, and your role sets how
many matches you play. Moving to a stronger league lowers your expected
rating, and so your growth, unless your key moments make up for it.

## Training intensity, fatigue and injuries

```
fatigue = previous × carryover + intensity_load + match_share × match_load
          + max(0, age − age_load_from) × age_load_per_year
```

- Reaching `injury_threshold` injures you **for the next season**: you
  miss `missed_match_share` of its matches *and* of its training. Fatigue
  then resets to `after_injury`.
- Normal training is sustainable for a young starter. Two intense seasons
  in a row cause an injury. Veterans tire faster.
- The season screen shows your fatigue and warns when the chosen intensity
  would end the season injured.
- Intense training (×1.2 growth) works as a one-season burst. Doing it
  every season backfires (`test_career_simulation.gd` checks this).

## Hall of Fame

```
score = peak overall × 1 + top-tier senior seasons × 2 + key moments won × 0.5
inducted if peak ≥ 88 and score ≥ 130
```

M6 adds trophies and the Golden Ball to the score.

## Design checks (`tests/unit/career/test_career_simulation.gd`)

Whole careers are simulated with a simple policy: take the best passable
trial, then sign the strongest affordable offer. The checks:

- No career gets stuck, at any position or play level.
- Elite play (9.7 average) ends in the top league and in the Hall of Fame.
- Good play (7.5) falls short of the Hall of Fame.
- Weak play (5.0) stays below the top league.
- Always training intensely ends with a lower peak than normal training.

## Save format

`CareerState.FORMAT_VERSION` is 2. `CareerMigration.migrate` upgrades
version 1 saves, adding the academy club, no contract and zero fatigue. It
never modifies its input. `validate_dict` rejects unknown versions and
unknown clubs.
