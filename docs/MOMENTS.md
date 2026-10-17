# 3D key moments

Each season has a few **key moments**: 3 in the academy (age 15 and below),
4 after that. They are played in real time with touch. Every result is decided
by the player's input. Ratings change the **margin for error** and never roll
dice. The rules live in `scripts/core/moments/`. The numbers live in
`data/moment_tuning.json`.

## Controls

| Moment | Controls |
|---|---|
| Penalty | Drag on the goal to aim. Then hold anywhere and release to set the power (the bar sweeps up and down). |
| Free kick | Drag to aim. Drag left or right to curl. Then hold and release for power. |
| One-on-one | The run starts at once. Tap the goal to shoot there, or press **Chip** or **Round**. Wait too long and the keeper smothers it. |
| Save (open play or penalty) | After the run-up the opponent shoots. Tap where the ball is going to dive there. |

Phones switch to landscape for moments and back to portrait for menus.
`ScreenFit` keeps text readable in both orientations.

## How each moment is judged

Goal-plane coordinates are x = metres from the goal centre and y = height.

- **Keeper reach** = body radius + (flight time − reaction delay) × dive speed.
  The ball's flight time comes from your power. The opposing keeper's dive
  speed comes from the competition strength. A shot outside the keeper's
  reach and inside the frame is a goal.
- **Penalty**:
  - Overhitting (power above the sweet spot) lifts the ball and pushes it wide.
  - Softer shots give the keeper more time.
  - Aim near the corners.
- **Free kick**:
  - The ball must get past the wall: over it (a softer, lofted shot) or round it (curl).
  - Then it must beat a keeper who reacts late because the wall blocks their view.
- **One-on-one**: the keeper rushes out, which shrinks the gap.
  - **Shoot**: the closer the keeper, the more of the goal they cover.
  - **Chip**: needs the keeper well off their line.
  - **Round**: only works inside a timing window.
- **Save**:
  - Your keeper moves towards where you tapped, starting when you tapped.
  - You save it if your keeper is within catch radius of the ball when it arrives.

## What ratings change (and nothing else does)

| Skill | Effect |
|---|---|
| Shooting | Slower power bar. Aim assist pulls shots up to 0.3 m outside the frame back in. Less overhit error. More finesse in one-on-ones. Easier chips. |
| Passing | More curl on free kicks. |
| Dribbling | Wider timing window for rounding the keeper. |
| Pace | Faster run in one-on-ones (less time, a bigger gap). |
| Goalkeeping | Faster dive and a bigger catch radius. |
| Opposition strength | Their keeper's dive speed. |

## Variety without luck

Moment types rotate through the position's list in
`schedule.by_position`, season by season. Staging details (free-kick distance
and wall side, where an opponent shoots) come from `Variety`. That is a fixed
integer hash of the season number and moment index, so a moment is identical
on every replay. It sets up the challenge only. The outcome still depends
only on the player's input.

## Effect on the season

```
season rating = expected rating + mean(moment deltas) × rating.weight
moment delta  = success ? lerp(success_min, success_max, quality) : failure
```

With the default numbers, perfect moments add **+4.0** and all failures cost
**−1.2**. A season rating near 9–10 is what reaching 99 needs (see
`docs/BALANCE.md`), so skill in the moments drives the whole career.
"Quick sim" skips the moments and uses the expected rating.

## Tuning

Edit `data/moment_tuning.json`, then run `./tools/run_tests.sh`.
`tests/unit/moments/` pins the intended behaviours. Examples: corners score,
central penalties are saved, low free kicks hit the wall, curl beats it, and
dribbling widens the rounding window.
