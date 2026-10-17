// Reads a career JSON on stdin and prints the plausibility result (used by
// tools/mock_supabase.py so the mock ranks careers exactly like the real
// edge function). Run: node --experimental-strip-types check_career_cli.ts
import { readFileSync } from "node:fs";
import { LIMITS } from "../supabase/functions/submit-ranking/limits.ts";
import { checkCareer } from "../supabase/functions/submit-ranking/plausibility.ts";

const career = JSON.parse(readFileSync(0, "utf8"));
process.stdout.write(JSON.stringify(checkCareer(career, LIMITS)));
