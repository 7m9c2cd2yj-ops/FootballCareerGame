# Cups and the Golden Ball

Rules live in `scripts/core/cups/`. Data is in `data/nations.json` (16
fictional nations with flags) and `data/cups.json` (cups, 12 foreign clubs,
match numbers, Golden Ball rivals). Cups are simulated at the end of each
season. They are not playable moments: the season you just played decides
your part in them.

## The cups

| Cup | When | Field | You play if |
|---|---|---|---|
| Continental Cup | every season | the 4 strongest top-tier Valdorian clubs + 12 foreign clubs | you are 18+ and your club is one of the 4 |
| World Nations Cup | every 4 seasons (`every_seasons`, `season_offset`) | all 16 nations | you are 18+ and your overall is at least `call_up_min` (70) |

Each cup is a knockout of 16 (round of 16, quarter-finals, semi-finals,
final). The draw is seeded by strength (1 v 16, 8 v 9, ...), so the top two
seeds can only meet in the final.

## How a match is decided (no dice)

```
your team's strength     = base strength + your contribution
any other team's strength = base strength + form
your contribution = ((your overall − team strength) × overall_influence
                    + (season rating − rating_baseline) × rating_influence)
                    × share of the season you played,
                    clamped to [min_contribution, max_contribution]
form = (Variety(season, match) − 0.5) × form_range
```

- The stronger side wins. Ties go to the higher base strength.
- Your season rating includes your key moments, so playing them well wins cups.
- Being on the bench or injured cuts your contribution.
- Your team never gets "form": your contribution replaces it.
- Form for computer-controlled teams comes from the fixed `Variety` hash. It
  is identical on every replay and cannot be re-rolled.
- Scorelines follow the strength gap. The losing side's goals are only
  flavour.

## Golden Ball (each senior season)

```
your score  = overall + (season rating − 6) × rating_weight + trophies this season × points_per_trophy
rival score = rival level + (Variety(season, rival) − 0.5) × form_range
```

Rank 1 wins. A top-3 finish is news. The 8 rivals are fictional players.

## Design checks

Measured with `test_career_simulation.gd`'s policy, one forward and one
goalkeeper:

| Play level | Continental Cups | Nations Cups | Golden Balls |
|---|---|---|---|
| Elite (9.7) | ~5 of 22 | ~1 of 5 | ~6 |
| Star (9.0) | ~3 of 22 | ~1 of 5 | ~1 |
| Very good (8.0) | ~1 | 0 | 0 |
| Good (7.5) | 0 | 0 | 0 |

The tests check that:
- elite careers win trophies and Golden Balls
- good careers never win a Golden Ball
- your contribution lifts your team
- draws are seeded and deterministic

## Display

The phone's **Cups** app shows the trophy cabinet, your Golden Ball
finishes and the latest season's brackets. Brackets are **recomputed**
from the season record, since the simulation is deterministic, so the save
stores only your cup runs and Golden Ball ranks (format version 4).
