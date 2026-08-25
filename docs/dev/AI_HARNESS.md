# Codex + Claude Code development harness

`./bin/harness` is the common control plane for plans, writer ownership, validation, handoff, and observable CLI usage. AI hooks call the same Python program; no LLM hook is used for deterministic checks.

## Daily loop

```bash
./bin/harness doctor
./bin/harness context
./bin/harness plan
./bin/harness claim TOOLCHAIN-001 --agent codex
./bin/harness verify --lane fast
./bin/harness verify --lane standard --target ios
./bin/harness handoff TOOLCHAIN-001 --from-agent codex --to claude \
  --summary "툴체인 고정 완료" --next "diff 검토"
```

`fast` routes only the affected stacks. `standard` is required before handoff, commit, or push. `full` runs all release builds and is required before deployment. Passed verification is stored against a content fingerprint, so a new edit invalidates the gate. Detailed logs and usage records live under ignored `.ai-harness/runtime/`; agent context receives only a short digest.

The local gate is a collaboration guardrail, not an adversarial security boundary: a process that can rewrite the repository can also tamper with local state. A protected CI check is the authoritative merge/release gate once the pinned toolchain task is complete.

## Collaboration policy

Only the task lease owner edits the current worktree. Claude normally performs bounded planning or final review while Codex implements. A second writer must use a separate worktree and branch. `release --force` is recovery-only for a stale lease.

The committed plan uses S/M/L budget classes rather than fictional subscription token balances. Codex Pro and Claude Max do not expose a stable repository-readable remainder. `dispatch` records usage fields emitted by each CLI and applies turn/time/optional soft-token limits:

```bash
./bin/harness dispatch --agent claude --role review --task TOOLCHAIN-001 --prompt-file /tmp/review.txt --dry-run
./bin/harness dispatch --agent codex --role implement --task TOOLCHAIN-001 --prompt-file /tmp/implement.txt --dry-run
./bin/harness usage
```

Claude defaults: Haiku/5 turns for exploration, Sonnet/8 for review, Sonnet/16 for implementation, Opus/10 only for architecture. Codex keeps the user's selected main model; support agents are capped at two and use Luna/Terra profiles.

## Local trust and CI

Claude reads `.claude/settings.json` automatically in a trusted checkout. Codex project hooks must be reviewed once with `/hooks`. Headless runs must only execute in trusted repositories; external pull requests need an isolated CI sandbox and API-key-based Claude `--bare` configuration.

`doctor --strict` resolves the repository-pinned mise toolchain before system tools and treats
Flutter, Node, or Firebase version drift as blocking. The Riverpod code generator compatibility
warning remains visible until the locked analyzer dependencies are upgraded. Native compile
recovery is tracked separately by `NATIVE-001`.
