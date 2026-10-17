// Run: node --experimental-strip-types --test backend/supabase/functions/submit-ranking/
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { LIMITS } from "./limits.ts";
import { checkCareer } from "./plausibility.ts";

const fixtures = new URL("../../../tests/fixtures/", import.meta.url);

function load(name: string): Record<string, any> {
  return JSON.parse(readFileSync(new URL(`${name}.json`, fixtures), "utf8"));
}

function problemsAfter(change: (career: Record<string, any>) => void): string[] {
  const career = load("elite_forward");
  change(career);
  const result = checkCareer(career, LIMITS);
  assert.equal(result.ok, false, "tampered career must be rejected");
  return result.problems;
}

const REAL_CAREERS = ["elite_forward", "average_keeper", "extreme_intense"];

test("real careers from the game pass and are summarized", () => {
  for (const name of REAL_CAREERS) {
    const result = checkCareer(load(name), LIMITS);
    assert.deepEqual(result.problems, [], name);
    assert.equal(result.summary?.seasons, 32);
  }
  const elite = checkCareer(load("elite_forward"), LIMITS).summary!;
  assert.equal(elite.peak_overall, 99);
  assert.equal(elite.inducted, true);
  assert.ok(elite.trophies > 0);
  const average = checkCareer(load("average_keeper"), LIMITS).summary!;
  assert.equal(average.inducted, false);
});

test("the server's summary matches the game's own", () => {
  for (const name of REAL_CAREERS) {
    const expected = load(`${name}.summary`);
    const summary = checkCareer(load(name), LIMITS).summary!;
    for (const key of Object.keys(expected)) {
      assert.equal(summary[key as keyof typeof summary], expected[key], `${name}.${key}`);
    }
  }
});

test("an overall jump the game cannot produce is rejected", () => {
  const problems = problemsAfter((c) => {
    c.history[5].overall_after = 99;
    c.history[6].overall_before = 99;
  });
  assert.ok(problems.some((p) => p.includes("impossible growth")));
});

test("rewriting history breaks continuity", () => {
  const problems = problemsAfter((c) => { c.history[10].overall_before = 40; });
  assert.ok(problems.some((p) => p.includes("does not continue")));
});

test("extra trophies are rejected", () => {
  const problems = problemsAfter((c) => {
    c.cup_runs.push({ season_number: 30, cup_id: "continental_cup", team: "x", wins: 4, won: true });
    c.cup_runs.push({ season_number: 30, cup_id: "continental_cup", team: "x", wins: 4, won: true });
  });
  assert.ok(problems.some((p) => p.includes("two continental_cup runs")));
});

test("a World Nations Cup in the wrong season is rejected", () => {
  const problems = problemsAfter((c) => {
    c.cup_runs.push({ season_number: 15, cup_id: "world_nations_cup", team: "valdoria", wins: 4, won: true });
  });
  assert.ok(problems.some((p) => p.includes("no World Nations Cup")));
});

test("trophies and awards before senior age are rejected", () => {
  const problems = problemsAfter((c) => {
    c.golden_balls.push({ season_number: 3, rank: 1, winner: "Test" });
  });
  assert.ok(problems.some((p) => p.includes("outside senior seasons")));
});

test("age must match the seasons played", () => {
  const problems = problemsAfter((c) => { c.player.age = 25; });
  assert.ok(problems.some((p) => p.includes("does not match")));
});

test("attributes above the cap are rejected", () => {
  const problems = problemsAfter((c) => { c.player.attributes.shooting = 150; });
  assert.ok(problems.some((p) => p.includes("out of range")));
});

test("garbage input is rejected without crashing", () => {
  for (const junk of [null, 42, "career", [], {}, { player: "x" }]) {
    assert.equal(checkCareer(junk, LIMITS).ok, false);
  }
});
