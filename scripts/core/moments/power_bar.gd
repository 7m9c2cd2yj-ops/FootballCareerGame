class_name PowerBar
extends RefCounted
## The hold-and-release power meter. It sweeps 0 -> 1 -> 0 once per period;
## better shooters get a longer period, so the sweet spot is easier to hit.


static func period(skill: float, tuning: MomentTuning) -> float:
	return tuning.by_skill("power_bar", "period_at_min_skill", "period_at_max_skill", skill)


## Power after holding for `elapsed` seconds (a triangle wave starting at 0).
static func value_at(elapsed: float, bar_period: float) -> float:
	var phase := fposmod(elapsed, bar_period) / bar_period
	return 1.0 - absf(2.0 * phase - 1.0)
