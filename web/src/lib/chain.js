// Names and small helpers that mirror the contracts' enums.
export const STATUS = ["None", "Committed", "Revealed", "Under review", "Rejected", "Disputed", "Paid", "Refunded"];
export const SEVERITY = ["Low", "Medium", "High", "Critical"];
export const LEVELS = ["Rookie", "Hacker", "Elite", "Legend"];
export const LEVEL_XP = [0, 100, 300, 700];

export const S = { None: 0, Committed: 1, Revealed: 2, UnderReview: 3, Rejected: 4, Disputed: 5, Paid: 6, Refunded: 7 };
export const CASE = { None: 0, Voting: 1, Resolved: 2 };

/** Waiting for the company: it can accept, reject or start a review. */
export const awaitingCompany = (status) => status === S.Revealed || status === S.UnderReview;

export function levelFor(xp) {
  let level = 1;
  for (let i = 1; i < LEVEL_XP.length; i++) if (Number(xp) >= LEVEL_XP[i]) level = i + 1;
  return level;
}
