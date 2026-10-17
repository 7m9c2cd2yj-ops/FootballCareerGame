// Keeps limits.ts in step with the game's data files.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { LIMITS } from "./limits.ts";

const data = new URL("../../../../data/", import.meta.url);
const read = (name: string) => JSON.parse(readFileSync(new URL(name, data), "utf8"));

test("limits match the game data", () => {
  const balance = read("balance.json");
  const rules = read("career_rules.json");
  const cups = read("cups.json");
  const clubs = read("clubs.json");
  assert.equal(LIMITS.startAge, balance.start_age);
  assert.equal(LIMITS.maxAge, balance.max_age);
  assert.equal(LIMITS.attributeMax, balance.attribute_max);
  assert.equal(LIMITS.seniorAge, rules.senior_age);
  assert.equal(LIMITS.nationsCupEvery, cups.world_nations_cup.every_seasons);
  assert.equal(LIMITS.nationsCupOffset, cups.world_nations_cup.season_offset);
  const hof = rules.hall_of_fame;
  assert.deepEqual(LIMITS.hallOfFame, {
    minPeakOverall: hof.min_peak_overall,
    inductionScore: hof.induction_score,
    pointsPerPeakOverall: hof.points_per_peak_overall,
    pointsPerTopTierSeason: hof.points_per_top_tier_season,
    pointsPerKeyMomentWon: hof.points_per_key_moment_won,
    pointsPerTrophy: hof.points_per_trophy,
    pointsPerGoldenBall: hof.points_per_golden_ball,
  });
  const topLeague = clubs.leagues.find((l: { tier: number }) => l.tier === 1).id;
  const topClubs = clubs.clubs.filter((c: { league: string }) => c.league === topLeague)
    .map((c: { id: string }) => c.id);
  assert.deepEqual(LIMITS.topTierClubs, topClubs);
  const moments = read("moment_tuning.json").schedule;
  assert.equal(LIMITS.maxKeyMomentsPerSeason, Math.max(moments.academy_moments, moments.senior_moments));
});

test("preset names match the database seed", () => {
  const names: string[] = read("preset_names.json").names;
  const sql = readFileSync(new URL("../../migrations/20261017120000_init.sql", import.meta.url), "utf8");
  const seeded = [...sql.matchAll(/^\s+\('([A-Za-z]+)'\)[,;]$/gm)].map((m) => m[1]);
  assert.deepEqual(seeded, names);
});

test("servers match the database seed", () => {
  const servers: string[] = read("online.json").servers.map((s: { id: string }) => s.id);
  const sql = readFileSync(new URL("../../migrations/20261017120000_init.sql", import.meta.url), "utf8");
  const seeded = [...sql.matchAll(/^\s+\('([a-z_]+)', '[^']+', 'region'\)[,;]$/gm)].map((m) => m[1]);
  assert.deepEqual(seeded, servers);
});
