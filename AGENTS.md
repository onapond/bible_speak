# Bible Speak agent contract

## Source of truth

- Shared plan: `.ai-harness/plan.json`; compact handoff: `.ai-harness/HANDOFF.md`.
- Run `./bin/harness context` at session start. Do not preload the old status archive.
- One task, one objective. Read only the task card and files required by its `allowedPaths`.

## Coordination

- Claim a writing task with `./bin/harness claim TASK-ID --agent codex|claude` before edits.
- Only the lease owner writes in this worktree. A reviewer remains read-only.
- Parallel writers require separate Git worktrees and branches (`codex/*` or `claude/*`).
- Handoff with `./bin/harness handoff TASK-ID ...`; never pass raw chat or full logs.

## Work loop

1. Confirm objective, affected paths, acceptance criteria, target, and budget class.
2. Inspect call sites before changing shared models, services, theme, or state.
3. Implement the smallest coherent slice; never expose provider secrets to Flutter/web assets.
4. Run `./bin/harness verify --lane fast` at checkpoints and `--lane standard` before handoff.
5. Allow at most two fix/rerun cycles for the same failure; then record a blocker.
6. A merge/release candidate requires `./bin/harness verify --lane full`.

## Quality and safety

- Flutter/Dart names use `snake_case`; Riverpod remains the state-management default.
- Preserve user data and account isolation. Test loading, empty, offline, auth-change, and error states.
- Do not commit `.env`, credentials, signing keys, provider keys, generated build output, or harness runtime logs.
- Stage explicit paths. Never force-push, amend, delete, deploy, or migrate production data unless requested.
- Use Firebase Functions/Secrets for privileged APIs. Client builds contain only public configuration.

## Context and model budget

- Subscription quota is not a reliable token counter. Treat limits as soft and record emitted CLI usage only.
- S: one agent. M: Codex implementation + Claude review. L/high-risk: bounded Claude plan, Codex implementation, Claude review.
- Use at most two support agents, one nesting level, and concise findings. Store full logs locally; show only the failing digest.
- Codex keeps the user's main model selection. Claude uses Haiku for scans, Sonnet for implementation/review, Opus only for high-risk architecture.
