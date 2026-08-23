@AGENTS.md

# Claude Code adapter

- `AGENTS.md` is the shared contract; do not duplicate it here.
- Start with `./bin/harness context --agent claude`.
- Before writing, claim the task. During review or architecture work, remain read-only and consume the diff plus `.ai-harness/HANDOFF.md`.
- Use the project agents in `.claude/agents/` for bounded exploration/review. Agent teams stay off unless the task card explicitly requires them.
- Prefer `/clear` between unrelated tasks and `/compact` only within one long task. Do not read `docs/status/sessions/` unless a task card names it.
- The repository is now developed on macOS. Use cross-platform commands from `./bin/harness`; old PowerShell key-injection instructions are obsolete and unsafe.
