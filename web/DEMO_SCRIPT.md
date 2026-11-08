# Demo script (about 6 minutes)

Setup once: `anvil`; in `contracts\`: Deploy then Seed; in `web\`: `pnpm sync` then `pnpm dev`.
MetaMask: import Anvil accounts 1 (company), 2 (hunter), 4 to 8 (jurors) from the Anvil printout. Account 3 is a second hunter.
Use ONE browser and http://localhost:3000 throughout (secrets are stored per site).

1. **Company (account 1)**: Programs, Create a program. Name it, keep tiers 5/15/30/50 and 10 ETH. Approve the 2 transactions. You land on the program page: vault, rewards table.
2. **Hunter (account 2)**: open the program, Submit a report. Fill title, private report, a short public summary, severity High. One button: commit, encrypt, upload, reveal. Show My reports (status Under review) and the vault bar (3 ETH now locked).
3. **Company**: Company page. Read report (decrypts in the browser, shows "matches the committed hash"). Accept and pay. Switch to the hunter: balance +3 ETH; Profile shows the badge and XP.
4. **Dispute**: hunter submits a second report. Company rejects it. Hunter: My reports, Dispute with the jury (approve, pay fee, escalate: show the three transactions).
5. **Jury**: switch to the three drawn jurors (the case page lists them): each commits a hidden vote. Click +6 min in the Demo bar. Each reveals. Anyone clicks Resolve. The hunter is paid at once; jurors share the fee.
6. **Timeout**: hunter submits a third report; company does nothing; click +11 min; hunter clicks "The company did not answer".
7. Close on Leaderboard and the live ticker, then show `contracts\SECURITY.md` (tests, fuzzing, invariants, the bugs found and fixed).
