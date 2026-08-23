---
name: dev-loop
description: Run the shared Bible Speak plan, implementation, and validation loop.
---

1. Run `./bin/harness context --agent claude` and `./bin/harness plan`.
2. Claim the selected task before edits: `./bin/harness claim TASK --agent claude`.
3. Stay inside the task card's allowed paths and acceptance criteria.
4. Run `./bin/harness verify --lane fast` at checkpoints. Retry the same failure at most twice.
5. Before review, run the task lane and target, then create a compact handoff.
6. Commit/push/deploy commands are automatically blocked if their validation fingerprint is missing or stale.

Do not use the retired PowerShell API-key injection flow. Privileged provider keys stay in server secrets.
