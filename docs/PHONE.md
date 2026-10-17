# The in-game phone: Clubs, News, Messages, Kickfie

Open it with **Phone** on the season screen. The home screen has four apps,
each with an unread badge:

| App | Shows |
|---|---|
| Clubs | Your club and contract, trials, offers, what every club wants (`docs/CAREER.md`). |
| News | A headline and short story for every career event, newest first. |
| Messages | Your agent: live advice about your situation now, then a text for past events. |
| Kickfie | A fake social feed: fan posts reacting to your career events. |

## Everything comes from real career events

Core career rules record a `CareerEvent` at the moment something happens. The
event holds only ids and numbers. The log is stored in the save (format version 3).

| Event | Recorded when | Values |
|---|---|---|
| `season_played` | a season ends | club, overall before/after, rating, key moments won/played |
| `milestone` | overall first reaches 50/60/70/80/90/99 | club, milestone |
| `injury` | fatigue causes an injury | club |
| `top_tier_debut` | first senior season in tier 1 | club |
| `trial_passed` / `trial_failed` | the trial is taken | club (and academy) |
| `transfer` | you join another club | from/to club, fee, wage |
| `renewal` | you renew with your club | club, wage, years |
| `retirement` | you retire or reach 40 | club, peak overall, score, inducted |

`scripts/core/news/event_text.gd` fills templates from
`data/text_templates.json`:

- **Placeholders.** Templates may only use their event's values plus
  `{player}`, `{position}`, `{age}` and `{season}`. Club events also get
  `{league}` and `{club_tag}`. The loader rejects anything else, and a test
  renders every event type to check that no `{...}` is left.
- **Mood variants.** Season stories are `great`, `steady` or `poor` by
  rating; the thresholds are in the file. Retirement is `inducted` or `not_inducted`.
- **Rotation.** Templates for the same variant are used in turn, so stories
  don't repeat back to back. Fan handles and like counts come from the
  `Variety` hash. The same career always reads the same.
- **Agent advice** (`scripts/core/news/agent_advice.gd`) is worked out live
  from the career and is not stored. It covers: trials due, contract ending
  or ended, fatigue high enough that a heavy season would injure you, how
  many clubs' open needs fit you, and the option to retire.

## Safety (young audience)

- **No user-generated text** reaches other players or the feed. Fan handles
  come from a preset list, and every post comes from templates.
- **The loader rejects** link markers (`http`, `www.`, `.com`, ...) and
  known real club, league or federation names (`ContentRules`). The club
  data is held to the same rules.
- **The tone is kind:** fans support the player after poor seasons, never mock.

## Adding or changing text

Edit `data/text_templates.json`, then run `./tools/run_tests.sh`. The tests
validate every template, render every event type, and check that consecutive
stories differ and that transfer stories mention the fee.
