// What a real career can look like. Mirrors the game's data files; the test
// limits.test.ts reads data/*.json and fails if these drift apart.

export interface Limits {
  formatVersion: number;
  startAge: number;
  maxAge: number;
  seniorAge: number;
  attributeMax: number;
  /** Highest overall a brand-new academy player can have. */
  maxStartOverall: number;
  /** Largest overall change in one season. Real careers peak at +8 / -3
   * (perfect ratings with intense training included, see fixtures); these
   * leave margin without letting a forged jump through. */
  maxSeasonGain: number;
  maxSeasonDrop: number;
  maxKeyMomentsPerSeason: number;
  /** World Nations Cup is held when (season + offset) % every == 0. */
  nationsCupEvery: number;
  nationsCupOffset: number;
  cupRounds: number;
  topTierClubs: string[];
  hallOfFame: {
    minPeakOverall: number;
    inductionScore: number;
    pointsPerPeakOverall: number;
    pointsPerTopTierSeason: number;
    pointsPerKeyMomentWon: number;
    pointsPerTrophy: number;
    pointsPerGoldenBall: number;
  };
}

export const LIMITS: Limits = {
  formatVersion: 4,
  startAge: 8,
  maxAge: 40,
  seniorAge: 18,
  attributeMax: 99,
  maxStartOverall: 20,
  maxSeasonGain: 11,
  maxSeasonDrop: 8,
  maxKeyMomentsPerSeason: 4,
  nationsCupEvery: 4,
  nationsCupOffset: 3,
  cupRounds: 4,
  topTierClubs: ["brackenford", "mistral_city", "copperlake", "thornvale", "stormhaven", "glimmerton", "ravenmoor", "saltmarsh"],
  hallOfFame: {
    minPeakOverall: 88,
    inductionScore: 130,
    pointsPerPeakOverall: 1,
    pointsPerTopTierSeason: 2,
    pointsPerKeyMomentWon: 0.5,
    pointsPerTrophy: 3,
    pointsPerGoldenBall: 8,
  },
};
