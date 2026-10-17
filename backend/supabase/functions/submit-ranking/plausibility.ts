// Server-side check of an uploaded career before it may be ranked. The client
// is never trusted: this re-derives the ranking summary from the full career
// history and rejects anything the game cannot produce. Pure (no Deno or
// network APIs), so it is unit-tested with Node.
import type { Limits } from "./limits.ts";

export interface Summary {
  position: string;
  peak_overall: number;
  seasons: number;
  trophies: number;
  golden_balls: number;
  hof_score: number;
  inducted: boolean;
  retired: boolean;
}

export interface CheckResult {
  ok: boolean;
  problems: string[];
  summary: Summary | null;
}

type Json = Record<string, unknown>;
const POSITIONS = ["GK", "DEF", "MID", "FWD"];

function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function num(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : NaN;
}

function list(value: unknown): Json[] {
  return Array.isArray(value) ? value.filter(isObject) : [];
}

export function checkCareer(career: unknown, limits: Limits): CheckResult {
  const problems: string[] = [];
  if (!isObject(career) || !isObject(career.player)) {
    return { ok: false, problems: ["career or player missing"], summary: null };
  }
  if (num(career.version) !== limits.formatVersion) {
    problems.push(`unsupported career version ${String(career.version)}`);
  }
  const history = list(career.history);
  checkPlayer(career.player as Json, history.length, limits, problems);
  checkHistory(history, limits, problems);
  const trophies = checkCupRuns(list(career.cup_runs), history, limits, problems);
  const goldenBalls = checkGoldenBalls(list(career.golden_balls), history, limits, problems);
  if (problems.length > 0) {
    return { ok: false, problems, summary: null };
  }
  return {
    ok: true,
    problems,
    summary: summarize(career, history, trophies, goldenBalls, limits),
  };
}

function checkPlayer(player: Json, seasons: number, limits: Limits, problems: string[]): void {
  if (!POSITIONS.includes(String(player.position))) problems.push("unknown position");
  const age = num(player.age);
  if (age !== limits.startAge + seasons) {
    problems.push(`age ${age} does not match ${seasons} seasons played`);
  }
  if (age > limits.maxAge) problems.push("older than the maximum age");
  const attributes = isObject(player.attributes) ? Object.values(player.attributes) : [];
  if (attributes.length === 0) problems.push("attributes missing");
  for (const value of attributes) {
    const n = num(value);
    if (!(n >= 1 && n <= limits.attributeMax)) problems.push(`attribute ${String(value)} out of range`);
  }
}

function checkHistory(history: Json[], limits: Limits, problems: string[]): void {
  let previous = NaN;
  history.forEach((season, index) => {
    const label = `season ${index + 1}`;
    if (num(season.season_number) !== index + 1) problems.push(`${label}: wrong number`);
    if (num(season.age) !== limits.startAge + index) problems.push(`${label}: wrong age`);
    const before = num(season.overall_before);
    const after = num(season.overall_after);
    if (!(after >= 1 && after <= limits.attributeMax)) problems.push(`${label}: overall out of range`);
    if (index === 0 && !(before <= limits.maxStartOverall)) problems.push(`${label}: start too high`);
    if (index > 0 && before !== previous) problems.push(`${label}: overall does not continue`);
    if (after - before > limits.maxSeasonGain) problems.push(`${label}: impossible growth`);
    if (before - after > limits.maxSeasonDrop) problems.push(`${label}: impossible drop`);
    const played = num(season.key_moments_played);
    const won = num(season.key_moments_won);
    if (!(played >= 0 && played <= limits.maxKeyMomentsPerSeason && won >= 0 && won <= played)) {
      problems.push(`${label}: impossible key moments`);
    }
    previous = after;
  });
}

function seniorSeason(history: Json[], season: number, limits: Limits): boolean {
  const record = history[season - 1];
  return record !== undefined && num(record.age) >= limits.seniorAge;
}

function checkCupRuns(runs: Json[], history: Json[], limits: Limits, problems: string[]): number {
  const seen = new Set<string>();
  let trophies = 0;
  for (const run of runs) {
    const season = num(run.season_number);
    const cup = String(run.cup_id);
    const key = `${cup}:${season}`;
    if (seen.has(key)) problems.push(`two ${cup} runs in season ${season}`);
    seen.add(key);
    if (!seniorSeason(history, season, limits)) problems.push(`${cup} run outside senior seasons`);
    if (cup === "world_nations_cup") {
      if ((season + limits.nationsCupOffset) % limits.nationsCupEvery !== 0) {
        problems.push(`no World Nations Cup in season ${season}`);
      }
    } else if (cup !== "continental_cup") {
      problems.push(`unknown cup ${cup}`);
    }
    const wins = num(run.wins);
    if (!(wins >= 0 && wins <= limits.cupRounds)) problems.push("impossible cup wins");
    if (run.won === true) {
      if (wins !== limits.cupRounds) problems.push("cup won without winning the final");
      trophies += 1;
    }
  }
  return trophies;
}

function checkGoldenBalls(balls: Json[], history: Json[], limits: Limits, problems: string[]): number {
  const seasons = new Set<number>();
  let won = 0;
  for (const ball of balls) {
    const season = num(ball.season_number);
    if (seasons.has(season)) problems.push(`two Golden Ball results in season ${season}`);
    seasons.add(season);
    if (!seniorSeason(history, season, limits)) problems.push("Golden Ball outside senior seasons");
    const rank = num(ball.rank);
    if (!(rank >= 1)) problems.push("impossible Golden Ball rank");
    if (rank === 1) won += 1;
  }
  return won;
}

function summarize(
  career: Json,
  history: Json[],
  trophies: number,
  goldenBalls: number,
  limits: Limits,
): Summary {
  const player = career.player as Json;
  let peak = 0;
  let topTier = 0;
  let momentsWon = 0;
  for (const season of history) {
    peak = Math.max(peak, num(season.overall_after));
    momentsWon += num(season.key_moments_won);
    if (num(season.age) >= limits.seniorAge && limits.topTierClubs.includes(String(season.club_id))) {
      topTier += 1;
    }
  }
  const hof = limits.hallOfFame;
  const score = peak * hof.pointsPerPeakOverall + topTier * hof.pointsPerTopTierSeason +
    momentsWon * hof.pointsPerKeyMomentWon + trophies * hof.pointsPerTrophy +
    goldenBalls * hof.pointsPerGoldenBall;
  return {
    position: String(player.position),
    peak_overall: peak,
    seasons: history.length,
    trophies,
    golden_balls: goldenBalls,
    hof_score: Math.round(score),
    inducted: peak >= hof.minPeakOverall && score >= hof.inductionScore,
    retired: career.retired === true,
  };
}
