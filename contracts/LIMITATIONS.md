# LIMITATIONS.md

Honest list of what this prototype does NOT do. Read before a demo or a viva.

## Jury selection uses on-chain pseudo-randomness (DisputeCourt)
Jurors are drawn with `block.prevrandao` mixed with the case id. A block proposer could influence this slightly, and a determined attacker who controls many juror addresses could try to improve their chances. This is acceptable for a testnet demo. **Production upgrade:** a verifiable random function such as Chainlink VRF.

## Jury size and collusion
The demo uses 3 jurors per case. With few jurors, two colluding jurors decide a case. Staking and slashing make dishonest voting costly, but they do not make it impossible. More jurors and larger stakes reduce the risk.

## Tie-break rule
When revealed votes are tied (including when nobody reveals): a case that came from a REJECTION goes to the company; a case that came from a company TIMEOUT goes to the hunter. This is a policy choice written into the contract, not a technical fact.

## Severity decided by the company
When the company accepts a report it chooses the final severity. A hunter cannot dispute "accepted, but at a lower severity than I claimed". A dispute can only be opened after a rejection or a timeout.

## Duplicate reports
The Registry records who committed first (`committedAt`), but a person decides which reports are duplicates. The contract cannot read an encrypted report.

## Report encryption
For disputes, the hunter re-wraps the report key so jurors can read the report. A production system would use threshold encryption or a trusted execution environment. Reports are encrypted in the browser; the contracts only store a hash and an IPFS address.

## The contracts cannot judge if a bug is real
They enforce process and payment. Humans (the company, then the jury) decide.

## Other
- Reveal locks funds: a program without enough unlocked ETH cannot accept more revealed reports until it is topped up.
- The Court's `reserve` (which pays the fee of timeout cases) must be funded by someone; with an empty reserve a timeout case simply has no fee and no reward for jurors except slashed stakes.
- Testnet only. No audit has been done; do not use with real funds.
